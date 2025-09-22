import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from pyspark.sql import Row
from awsglue.job import Job
import boto3
import time
import json
from botocore.exceptions import ClientError
from datetime import datetime
import sys
import os
import base64
import json
import time
from datetime import datetime
from typing import Optional, List, Dict, Any

from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from pyspark.sql import Row
from awsglue.job import Job

import boto3
from botocore.exceptions import ClientError
from email.mime.text import MIMEText


## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ["JOB_NAME"])

# Initialize Glue context and job
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)
job_name = args["JOB_NAME"]

# SES config (can be overridden via environment variables)
ses_region = os.environ.get("SES_REGION", "us-east-1")
sender_email = os.environ.get("SENDER_EMAIL", "noreply@example.com")
recipient_email = os.environ.get(
    "RECIPIENT_EMAIL"
)  # optional; fallback can be provided by secrets


def datetime_handler(x: Any) -> str:
    if isinstance(x, datetime):
        return x.isoformat()
    raise TypeError("Unknown type")


def get_secret(secret_name: str, region_name: str) -> Optional[str]:
    """Retrieve secret value from AWS Secrets Manager. Returns a string (SecretString) or None."""
    session = boto3.session.Session()
    client = session.client(service_name="secretsmanager", region_name=region_name)
    try:
        resp = client.get_secret_value(SecretId=secret_name)
        if "SecretString" in resp and resp["SecretString"]:
            return resp["SecretString"]
        if "SecretBinary" in resp and resp["SecretBinary"]:
            return base64.b64decode(resp["SecretBinary"]).decode("utf-8")
        return None
    except ClientError:
        raise


def send_email(
    subject: str, body: str, to_addresses: List[str], region: str = ses_region
) -> Dict[str, Any]:
    ses_client = boto3.client("ses", region_name=region)
    try:
        response = ses_client.send_email(
            Source=sender_email,
            Destination={"ToAddresses": to_addresses},
            Message={
                "Subject": {"Data": subject},
                "Body": {"Text": {"Data": body}},
            },
        )
        print("Email sent! Message ID:", response.get("MessageId"))
        return response
    except Exception as e:
        print("Error sending email:", str(e))
        raise


# mapping of job name prefixes to environment
prefixes = [
    ["hsfr-d", "dev"],
    ["hsfr-i", "int"],
    ["hsfr-q", "qa"],
    ["hsfr-t", "test"],
    ["hsfr-u", "uat_rel"],
    ["hsfr-p", "prod"],
]
prefix = next((p[0] for p in prefixes if p[0] in job_name), None)
env = next((p[1] for p in prefixes if p[0] in job_name), None)

if prefix is None:
    raise RuntimeError(f"Could not detect environment prefix from job name: {job_name}")

table = prefix.replace("-", "_")


region_name = os.environ.get("AWS_REGION", "us-east-1")
redshift_secret_name = f"{prefix}-redshift-force-etl-user"
secret_response = get_secret(redshift_secret_name, region_name)
if not secret_response:
    raise RuntimeError(f"No secret found for {redshift_secret_name} in {region_name}")

# Try to parse secret as JSON if possible
try:
    redshift_secret = json.loads(secret_response)
except Exception:
    # if secret is plain string, raise a helpful error
    raise RuntimeError(
        "Redshift secret must be a JSON string containing cluster_name, database, username"
    )

redshift_cluster_name = redshift_secret.get("cluster_name")
redshift_db_name = redshift_secret.get("database")
redshift_db_user_name = redshift_secret.get("username")
redshift_client = boto3.client("redshift-data")


# Redshift query
redshift_query = """
SELECT DISTINCT
    js.table_name AS target_table,
    sch.exec_status AS trigger_status,
    sch.crt_ts AS trigger_time,
    sch.error_msg AS scheduling_error,
    col.table_name AS src_table,
    col.start_time AS collctn_job_start_time,
    col.end_time AS collctn_job_end_time,
    col.execution_status AS collctn_exec_status,
    col.records_processed AS collctn_recs_prcsd,
    col.error_msg AS collctn_error,
    pub.subjob_id AS pub_subjob_id,
    pub.start_time AS pub_job_start_time,
    pub.end_time AS pub_job_end_time,
    pub.execution_status AS pub_exec_status,
    pub.error_msg AS pub_error,
    js.validation_value AS ROW_COUNT,
    tr.tbl_rows AS total_tbl_rows,
    js.insert_date AS load_date,
    col.query_executed as query_executedn
FROM
    audit_control.job_scheduling_status sch
    LEFT JOIN audit_control.job_exec_status_hist col ON col.run_id::text = sch.run_id::text AND col.job_phase = 1
    LEFT JOIN audit_control.job_exec_status_hist pub ON pub.run_id::text = sch.run_id::text AND pub.job_phase = 2
    LEFT JOIN audit_control.job_status js ON js.run_id::text = sch.run_id::text AND js.validation_type::text = 'ROW_COUNT'::character VARYING::text
    LEFT JOIN (
        SELECT sti."schema" || '.' || sti."table" AS tr_table, sti.tbl_rows
        FROM svv_table_info sti
    ) tr ON tr.tr_table = js.table_name::text
WHERE
    to_char(sch.crt_ts, 'YYYYMMDD') = to_char(CURRENT_DATE, 'YYYYMMDD')
"""


def parse_redshift_results(response_get: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Convert redshift-data get_statement_result output into list of dicts using ColumnMetadata."""
    cols = [c.get("name") for c in response_get.get("ColumnMetadata", [])]
    rows = []
    for record in response_get.get("Records", []):
        # each record is a list of single-key dicts like {'stringValue': '...'}
        values = []
        for cell in record:
            # cell can have stringValue, longValue, booleanValue, doubleValue, etc.
            if "stringValue" in cell:
                values.append(cell["stringValue"])
            elif "longValue" in cell:
                values.append(cell["longValue"])
            elif "booleanValue" in cell:
                values.append(cell["booleanValue"])
            elif "doubleValue" in cell:
                values.append(cell["doubleValue"])
            else:
                values.append(None)
        # map columns to values (if columns missing, fallback to positional names)
        if cols and len(cols) == len(values):
            rows.append(dict(zip(cols, values)))
        else:
            rows.append({f"col_{i}": v for i, v in enumerate(values)})
    return rows


print(redshift_query)

try:
    response = redshift_client.execute_statement(
        ClusterIdentifier=redshift_cluster_name,
        Database=redshift_db_name,
        DbUser=redshift_db_user_name,
        Sql=redshift_query,
    )
except Exception as e:
    error_msg = f"Error occurred while executing query: {str(e)}"
    print(error_msg)
    result_json = json.dumps({"error": error_msg})
else:
    # poll until finished or error
    statement_id = response.get("Id")
    if not statement_id:
        raise RuntimeError("No statement id returned from execute_statement")

    # simple poll loop
    for _ in range(60):
        desc = redshift_client.describe_statement(Id=statement_id)
        status = desc.get("Status")
        if status in ("FINISHED", "ABORTED", "FAILED"):
            break
        time.sleep(1)

    if status != "FINISHED":
        result_json = json.dumps(
            {"status": status, "details": desc}, default=datetime_handler
        )
    else:
        response_get = redshift_client.get_statement_result(Id=statement_id)
        parsed = parse_redshift_results(response_get)
        result_json = json.dumps({"rows": parsed}, indent=2, default=datetime_handler)


# Specify email subject and body
email_subject = "Redshift Query Results"
email_body = result_json

# Send email if recipient is available
if recipient_email:
    try:
        send_email(email_subject, email_body, [recipient_email])
    except Exception:
        print("Failed to send email; continuing")

# commit Glue job
job.commit()

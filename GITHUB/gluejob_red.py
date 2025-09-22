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
from email import encoders
from email.mime.base import MIMEBase
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from string import Template

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
#job = Job(spark)
#job.init(args['JOB_NAME'], args)
#job.commit()
job_name = args['JOB_NAME']
ses_region =  'us-east-1'
sender_email = 'abc’
def datetime_handler(x):
    if isinstance(x, datetime):
        return x.isoformat()
    raise TypeError("Unknown type")
    
def get_secret(secret_name, region_name):
    """ Function to retrieve secrets from secret manager"""
    # Create a Secret Manager Client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secrets = client.get_secret_value(SecretId=secret_name)
        if 'SecretString' in get_secrets:
            secret = get_secrets['SecretString']
            return secret
        else:
            decoded_binary_secret = base64.b64decode(get_secrets['SecretBinary'])
            return decoded_binary_secret

    except Exception as e:
        raise e
        
   #Function to send email using SES
def send_email(subject, body):
    ses_client = boto3.client("ses", region_name=ses_region)
    CHARSET = "UTF-8"
    try:
        response = ses_client.send_email(
            Source=sender_email,  # replace with your sender email
            Destination={
                'ToAddresses': [recipient_email],
            },
            Message={
                'Subject': {'Data': subject},
                'Body': {'Text': {'Data': body}},
            }
        )
        print("Email sent! Message ID:", response["MessageId"])
        print("sender_email", sender_email)
        print("Reciever mail", recipient_email)
        print("body", body)
        print("Response", response)
    except Exception as e:
        print("Error sending email:", str(e))    
prefixes = [['hsfr-d','dev'],['hsfr-i', 'int'], ['hsfr-q','qa'], ['hsfr-t','test'], ['hsfr-u','uat/rel'],['hsfr-p','prod']]
prefix = next((p[0] for p in prefixes if p[0] in job_name), None)
env = next((p[1] for p in prefixes if p[0] in job_name), None)
table = prefix.replace('-','_')



region_name = "us-east-1"
redshift_secret_name = prefix + '-redshift-force-etl-user'
secret_response = get_secret(redshift_secret_name, region_name)
redshift_secret = json.loads(secret_response)
redshift_cluster_name = redshift_secret['cluster_name']
redshift_db_name = redshift_secret['database']
redshift_db_user_name = redshift_secret['username']
redshift_client = boto3.client('redshift-data')


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
            SELECT sti."schema" + '.'::character VARYING::text + sti."table" AS tr_table, sti.tbl_rows
            FROM svv_table_info sti
        ) tr ON tr.tr_table = js.table_name::text
    WHERE
        to_char(sch.crt_ts, 'YYYYMMDD') = to_char(CURRENT_DATE, 'YYYYMMDD')"""

print(redshift_query)

try:
    response = redshift_client.execute_statement(ClusterIdentifier = redshift_cluster_name, Database = redshift_db_name , DbUser = redshift_db_user_name , Sql = redshift_query)
except Exception as e:
    error_msg = "Error occured while executing {0} ".format(redshift_query)
else:
    time.sleep(2)
    response_dec = redshift_client.describe_statement(Id=response['Id'])

    if (response_dec['Status'] == 'FINISHED'):
        response_get = redshift_client.get_statement_result(Id=response['Id'])
        records = response_get['Records']
        print(records)
print("response",response)
result_json = json.dumps(response, indent=2, default=datetime_handler)




# Specify email subject and body
email_subject = "Redshift Query Results"
#email_body = "Test Mail"
email_body = result_json
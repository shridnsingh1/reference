Redshift Stored procedures 


DO
$$
	DECLARE
		start_time time:= NOW();
	BEGIN
		RAISE NOTICE 'Starting at %s: ',start_time;
		PERFORM pg_sleep(2);
		RAISE NOTICE 'Next time %s: ',start_time;
		
	END;
$$	
LANGUAGE plpgsql;



-- Stored Procedure: Aggregate Sales by Customer
CREATE OR REPLACE PROCEDURE sp_aggregate_sales()
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM reporting.sales_summary;

  INSERT INTO reporting.sales_summary (customer_id, total_sales, last_order_date)
  SELECT
    customer_id,
    SUM(order_total),
    MAX(order_date)
  FROM curated.orders_cleaned
  GROUP BY customer_id;
END;
$$;


-- Stored Procedure: Log Procedure Execution Metadata
CREATE OR REPLACE PROCEDURE sp_log_run_history(proc_name VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO audit.procedure_run_log (procedure_name, run_timestamp)
  VALUES (proc_name, current_timestamp);
END;
$$;


-- Stored Procedure: Clean and Deduplicate Customers
CREATE OR REPLACE PROCEDURE sp_transform_customers()
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM curated.customers_cleaned;

  INSERT INTO curated.customers_cleaned (customer_id, name, email)
  SELECT DISTINCT customer_id, name, email
  FROM stg.customers
  WHERE email IS NOT NULL;
END;
$$;

-- Stored Procedure: Transform and Load Orders Data
CREATE OR REPLACE PROCEDURE sp_transform_orders()
LANGUAGE plpgsql
AS $$
BEGIN
  TRUNCATE TABLE curated.orders_cleaned;

  INSERT INTO curated.orders_cleaned (order_id, customer_id, order_date, order_total, tax_amount)
  SELECT
    order_id,
    customer_id,
    CAST(order_date AS DATE),
    order_total,
    order_total * 0.05
  FROM stg.orders
  WHERE order_status NOT IN ('CANCELLED');
END;
$$;


************************************************************

-- Create audit log table (if not already exists)
CREATE TABLE IF NOT EXISTS audit.procedure_run_log (
    proc_name      VARCHAR(100),
    run_ts         TIMESTAMP DEFAULT GETDATE(),
    status         VARCHAR(20),
    row_count      BIGINT,
    error_message  VARCHAR(500)
);

-- Stored Procedure Template
CREATE OR REPLACE PROCEDURE sp_transform_orders()
LANGUAGE plpgsql
AS $$
DECLARE
    v_row_count BIGINT;
BEGIN
    -- Start transformation (atomic step)
    TRUNCATE TABLE curated.orders_cleaned;

    INSERT INTO curated.orders_cleaned (order_id, customer_id, order_date, order_total, tax_amount)
    SELECT
        order_id,
        customer_id,
        CAST(order_date AS DATE),
        order_total,
        order_total * 0.05
    FROM stg.orders
    WHERE order_status NOT IN ('CANCELLED');

    -- Capture inserted row count
    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    -- Log success
    INSERT INTO audit.procedure_run_log (proc_name, status, row_count, error_message)
    VALUES ('sp_transform_orders', 'SUCCESS', v_row_count, NULL);

EXCEPTION
    WHEN OTHERS THEN
        -- Log failure with error message
        INSERT INTO audit.procedure_run_log (proc_name, status, row_count, error_message)
        VALUES ('sp_transform_orders', 'FAILED', NULL, SQLERRM);

        -- Optionally re-raise error to stop upstream jobs
        RAISE;
END;
$$;



CALL sp_transform_orders();

Example Run Log:

SELECT * FROM audit.procedure_run_log ORDER BY run_ts DESC;

-- Sample Output
proc_name           | run_ts                  | status   | row_count | error_message
--------------------+-------------------------+----------+-----------+------------------------
sp_transform_orders | 2025-09-18 12:02:15 UTC | SUCCESS  |     15234 | null
sp_transform_orders | 2025-09-17 12:02:15 UTC | FAILED   |      null | "invalid input syntax"



Loop Types in Redshift Stored Procedures
1. Basic LOOP

Runs until explicitly exited.

CREATE OR REPLACE PROCEDURE sp_basic_loop()
LANGUAGE plpgsql
AS $$
DECLARE
    counter INT := 1;
BEGIN
    LOOP
        RAISE INFO 'Iteration: %', counter;
        counter := counter + 1;

        EXIT WHEN counter > 5; -- Exit condition
    END LOOP;
END;
$$;


👉 Prints 5 iterations.

2. WHILE LOOP

Runs while a condition is true.

CREATE OR REPLACE PROCEDURE sp_while_loop()
LANGUAGE plpgsql
AS $$
DECLARE
    counter INT := 1;
BEGIN
    WHILE counter <= 5 LOOP
        RAISE INFO 'Counter: %', counter;
        counter := counter + 1;
    END LOOP;
END;
$$;

3. FOR Loop over Range

Iterates through a numeric range.

CREATE OR REPLACE PROCEDURE sp_for_loop()
LANGUAGE plpgsql
AS $$
BEGIN
    FOR i IN 1..5 LOOP
        RAISE INFO 'Value: %', i;
    END LOOP;
END;
$$;








FOR Loop over Result Set (Cursor style)

Iterates over query results.

CREATE OR REPLACE PROCEDURE sp_cursor_loop()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT customer_id, SUM(order_total) AS total
               FROM stg.orders
               GROUP BY customer_id
    LOOP
        RAISE INFO 'Customer % has total %', rec.customer_id, rec.total;
        -- Example: insert into audit table
        INSERT INTO audit.customer_totals(customer_id, total_sales)
        VALUES (rec.customer_id, rec.total);
    END LOOP;
END;
$$;

Best Practices for Loops in Redshift

🚫 Don’t loop over millions of rows — it kills performance. Use set-based SQL.

✅ Use loops only for:
Calling multiple stored procedures in sequence
Running dynamic SQL for multiple tables/partitions
Small result sets (lookups, audit logging)
✅ Always add an EXIT WHEN condition to prevent infinite loops.
✅ Use RAISE INFO for debugging inside loops.



RECORD is a composite, temporary data type in PL/pgSQL.
It can hold a single row of data with fields matching the query you assign.
Unlike a fixed row type, it is dynamic — structure depends on the query.
Fields are accessed with dot notation (rec.column_name).

Example 1: Simple RECORD in a Loop

CREATE OR REPLACE PROCEDURE sp_use_record()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
BEGIN
    -- Iterate over query result into RECORD
    FOR rec IN SELECT customer_id, order_total 
               FROM stg.orders 
               WHERE order_status = 'COMPLETE'
               LIMIT 5
    LOOP
        RAISE INFO 'Customer: %, Order Total: %', rec.customer_id, rec.order_total;
    END LOOP;
END;
$$;


Example 2: RECORD with Dynamic Queries (EXECUTE INTO)
CREATE OR REPLACE PROCEDURE sp_dynamic_record()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
BEGIN
    EXECUTE 'SELECT COUNT(*) AS total_orders, MAX(order_date) AS last_order 
             FROM stg.orders'
    INTO rec;

    RAISE INFO 'Total Orders: %, Last Order Date: %', rec.total_orders, rec.last_order;
END;
$$;


Example 3: RECORD in a Cursor Loop
CREATE OR REPLACE PROCEDURE sp_record_cursor()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT DISTINCT customer_id, SUM(order_total) AS total
               FROM stg.orders
               GROUP BY customer_id
               LIMIT 3
    LOOP
        INSERT INTO audit.customer_summary (customer_id, total_sales, run_ts)
        VALUES (rec.customer_id, rec.total, GETDATE());
    END LOOP;
END;
$$;

Best Practices with RECORD
Best Practice	Why
Use for dynamic result sets	No need to predefine structure
Don’t use RECORD for wide/large datasets	It’s row-by-row → hurts performance
Prefer ROWTYPE if schema is known	More stable, e.g. rec stg.orders%ROWTYPE
Use RAISE INFO for debugging	Helps print field values



RAISE is used for logging, debugging, or throwing errors inside stored procedures.
Variants in Redshift:
RAISE INFO → writes an informational message to logs (non-blocking).
RAISE WARNING → logs a warning but continues execution.
RAISE EXCEPTION → logs an error and stops execution (like throw).


Example 1: Debugging with RAISE INFO
CREATE OR REPLACE PROCEDURE sp_test_raise()
LANGUAGE plpgsql
AS $$
DECLARE
    counter INT := 1;
BEGIN
    WHILE counter <= 3 LOOP
        RAISE INFO 'Counter value is %', counter;
        counter := counter + 1;
    END LOOP;
END;
$$;

Output in system logs (SVL_STATEMENTTEXT / CloudWatch):

INFO:  Counter value is 1
INFO:  Counter value is 2
INFO:  Counter value is 3



Example 2: RAISE INFO with a Record
CREATE OR REPLACE PROCEDURE sp_loop_customers()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT customer_id, order_total
               FROM stg.orders
               LIMIT 2
    LOOP
        RAISE INFO 'Customer: %, Order Total: %', rec.customer_id, rec.order_total;
    END LOOP;
END;
$$;


Logs:

INFO:  Customer: 101, Order Total: 250.00
INFO:  Customer: 102, Order Total: 175.50


Example 3: Logging Errors Gracefully
CREATE OR REPLACE PROCEDURE sp_safe_transform()
LANGUAGE plpgsql
AS $$
BEGIN
    BEGIN
        -- risky query
        INSERT INTO curated.orders_cleaned
        SELECT * FROM stg.orders_invalid; -- might fail
    EXCEPTION
        WHEN OTHERS THEN
            RAISE INFO 'Error during insert: %', SQLERRM; -- #Logs an INFO message with the error instead of crashing silently.
    END;
END;
$$;


Best Practices for RAISE INFO
Tip	Why
Use in development/debugging	Helps trace stored procedure steps
Use for audit logging	To show start/end of steps
Don’t overuse in production	Too many logs → noise in CloudWatch
For critical errors → RAISE EXCEPTION	To stop execution immediately

What is RAISE EXCEPTION?
RAISE EXCEPTION is used to throw an error from inside a stored procedure.
When raised, it:
Logs the error (visible in system logs / CloudWatch).
Aborts execution of the stored procedure immediately (rollback).
Returns the error to the client (like throw in other languages).


Example 1: Simple RAISE EXCEPTION
CREATE OR REPLACE PROCEDURE sp_test_exception()
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Something went wrong!';
END;
$$;





*******************************

CREATE OR REPLACE PROCEDURE dw_rpt.sproc_ndc_format(run_id character varying(256), date_run character varying(256))
 LANGUAGE plpgsql
AS $$
DECLARE 
 db VARCHAR(100) := current_database(); 
 source_table varchar(100) = '"'||db||'"."stg_rpt"."src_ndc_format"'; 
 sc varchar(100) = 'dw_rpt'; 
 ad varchar(100) = 'job_status'; 
 er varchar(100) = 'error_log'; 
 audit_db varchar(100) = ''||db||''; 
 audit_schema varchar(100) = 'audit_control'; 
 audit_job_validation_results_table varchar(100) = 'job_validation_results'; 
 var_current_date date = date_run; 
 file_name varchar(250); 
 prefix varchar(50); 
 var_cur_bucket varchar(100); 
 var_region varchar(100); 
 var_iam_role varchar(100); 
 batch_date date; 
 start_time timestamp; 
 end_time timestamp; 
 var_src_row_count bigint; 
 var_copy_id bigint; 
 var_tgt_count bigint; 
 var_src_count bigint; 
 var_subjob_id varchar(100) = '100059'; 
 var_subjob_id_1 varchar(100) = '100060'; 
 var_failed_rows bigint; 
 var_row_count bigint; 
 var_run_id bigint; 
 var_dim_count bigint; 
 var_stdm_test_1 bigint; 
 val_src_count bigint; 
 BEGIN IF db ='hsfr_sand_rpt_db' then prefix := 'hsfr-d'; 
 elseif db = 'hsfr_d_rpt_db' THEN prefix := 'hsfr-d'; 
 elseif db = 'hsfr_i_rpt_db' THEN prefix := 'hsfr-i'; 
 elseif db = 'hsfr_u_rpt_db' THEN prefix := 'hsfr-u'; 
 elseif db = 'hsfr_p_rpt_db' THEN prefix := 'hsfr-p'; 
 elseif db = 'hsfr_q_rpt_db' THEN prefix := 'hsfr-q'; 
 END IF; 
 /TRUNCATING STAGING TABLE/
 EXECUTE 'truncate table '||source_table||''; 
 COMMIT; 
 var_cur_bucket := param_value FROM audit_control.config_details WHERE param_name='CUR_BUCKET'; 
 var_region := param_value FROM audit_control.config_details WHERE param_name='REGION'; 
 var_iam_role := param_value FROM audit_control.config_details WHERE param_name='IAM_ROLE'; 
 batch_date := quote_literal(CURRENT_DATE); 
file_name := 's3://'||prefix||var_cur_bucket||'/'||prefix||'-cur-pull-ndc-format/batchdate='||var_current_date||'/';
 start_time := getdate(); 
 /COPY DATA FROM S3 TO STAGING TABLE/ 
EXECUTE 'copy '||source_table||' from '''||file_name||''' iam_role '''||var_iam_role||''' FORMAT AS PARQUET '; 
COMMIT; 
end_time := getdate(); 
var_src_row_count := count(1) from STG_RPT.SRC_NDC_FORMAT; 
var_copy_id := PG_LAST_COPY_ID(); 
var_tgt_count := PG_LAST_COPY_COUNT(); 
var_src_count := sum(lines_scanned) from stl_load_commits where query in (var_copy_id) and lines_scanned > 0; 
  
 /LOGGING AUDIT TABLES FOR SOURCE TABLE/
  EXECUTE 'Insert into "'||audit_schema||'"."'||ad||'" (run_id,table_name,file_name,batch_id,validation_type,validation_value,insert_date,job_start_time,job_end_time) Select '''||run_id||''',''src_ndc_format'','''||file_name||''',''0'',''ROW_COUNT'','''||var_src_row_count||''','''||batch_date||''','''||start_time||''','''||end_time||''''; 
 COMMIT; 
 EXECUTE 'Insert into "'||audit_schema||'"."'||ad||'" (run_id,table_name,file_name,batch_id,validation_type,validation_value,insert_date,job_start_time,job_end_time) Select '''||run_id||''',''src_ndc_format'','''||file_name||''',''0'',''STATUS'',''1'','''||batch_date||''','''||start_time||''','''||end_time||''''; 
 COMMIT; 
 /NUMBER OF RECORDS NOT UPLOADED INTO THE STAGING TABLE/ 
 CALL audit_control.gen_run_id('1',var_subjob_id); 
 COMMIT; 
 var_run_id := * FROM #my_temp; 
 var_failed_rows = var_src_count - var_tgt_count; 
 EXECUTE 'INSERT INTO "'|| audit_db ||'"."'|| audit_schema ||'"."'|| audit_job_validation_results_table ||'"(SUBJOB_ID,RULE_ID,TABLE_NAME,BATCH_RUNDATE,JOB_RUNID,SRC_COUNT,TGT_COUNT,TEST_RESULT,COMMENTS,RUN_ID) SELECT '||var_subjob_id||' as SUBJOB_ID ,''1'' as RULE_ID,''src_ndc_format'' as TABLE_NAME, current_date as BATCH_RUNDATE,'|| var_run_id ||' as JOB_RUNID, '|| var_src_count ||' as SRC_COUNT,'|| var_tgt_count ||' as TGT_COUNT,case when '||var_failed_rows||'=0 then ''Pass'' else ''Fail'' end as TEST_RESULT, ''Number of records not uploaded in staging table ='|| var_failed_rows ||''' as COMMENTS,'''||run_id||''' as RUN_ID'; 
 COMMIT; 
 /TRUNCATING DIM_NDC_FORMAT TABLE(FOR FULL LOAD)/ EXECUTE 'TRUNCATE TABLE "'||db||'"."'||sc||'".DIM_NDC_FORMAT'; 
 COMMIT; 
 batch_date := quote_literal(CURRENT_DATE); 
 start_time := getdate(); 
 /POPULATE DIM_NDC_FORMAT/ EXECUTE 'INSERT INTO DW_RPT.DIM_NDC_FORMAT 
    (NDC_FORMAT_CD_ID,NDC_FORMAT_CD,NDC_FORMAT_DESC,WAREHOUSE_DT,WAREHOUSE_TIM,CRT_BY_FILE,CRT_DT,UPDT_DT,UPDT_BY_FILE,END_DT,SRC_ID) 
        SELECT DISTINCT CHECKSUM(CAST(CONCAT(M.ORG_ID,NDC_FORMAT_CDE) AS VARCHAR)) AS NDC_FORMAT_CD_ID, 
        M.NDC_FORMAT_CDE AS NDC_FORMAT_CD, 
        M.DSC AS NDC_FORMAT_DESC,
        M.WAREHOUSE_DTE AS WAREHOUSE_DT,
        M.WAREHOUSE_TIM AS WAREHOUSE_TIM,
        M.CRT_BY_FILE AS CRT_BY_FILE,
        M.CRT_DT AS CRT_DT,
        CAST(NULL AS DATE) AS UPDT_DT, 
        NULL AS UPDT_BY_FILE,
        CAST(NULL AS DATE) AS END_DT, 
        M.ORG_ID AS SRC_ID
       FROM '||source_table||' M';
 COMMIT; 

end_time := getdate(); 
 var_row_count := sum(rows) AS inserted_rows FROM stl_insert WHERE query=pg_last_query_id(); 
 EXECUTE 'CALL "'||db||'"."'||sc||'".sproc_audit_log('''||audit_db||''','''||audit_schema||''','''||ad||''','''||run_id||''',''DIM_NDC_FORMAT'',''1'',''ROW_COUNT'','''||var_row_count||''','''||batch_date||''','''||start_time||''','''||end_time||''')'; 
 COMMIT; 
 EXECUTE 'CALL "'||db||'"."'||sc||'".sproc_audit_log('''||audit_db||''','''||audit_schema||''','''||ad||''','''||run_id||''',''DIM_NDC_FORMAT'',''1'',''STATUS'',''1'','''||batch_date||''','''||start_time||''','''||end_time||''')'; 
 COMMIT; 
 /RULE 1 for DIM_NDC_FORMAT/CALL audit_control.gen_run_id('1',var_subjob_id_1); 
 COMMIT; 
 var_run_id := * FROM #my_temp; 
 EXECUTE 'INSERT INTO "'|| audit_db ||'"."'|| audit_schema ||'"."'|| audit_job_validation_results_table ||'"(SUBJOB_ID,RULE_ID,TABLE_NAME,BATCH_RUNDATE,JOB_RUNID,TEST_RESULT,COMMENTS,RUN_ID) SELECT '|| var_subjob_id_1 ||' as SUBJOB_ID ,''1'' as RULE_ID,''DIM_NDC_FORMAT'' as TABLE_NAME, current_date as BATCH_RUNDATE,'|| var_run_id ||' as JOB_RUNID, case when count(1)>0 then ''Fail'' else ''Pass'' end as TEST_RESULT, case when count(1)>0 then ''NDC_FORMAT_CD_ID has duplicate records'' else ''NDC_FORMAT_CD_ID has unique records'' end as COMMENTS,'''||run_id||''' as RUN_ID FROM(select case when count(1)>1 then ''Fail'' else ''Pass'' end as duplicate_check FROM "'||db||'"."'||sc||'".DIM_NDC_FORMAT group by NDC_FORMAT_CD_ID) WHERE DUPLICATE_CHECK=''Fail'' '; 
 COMMIT; 
 /RULE 2 for DIM_NDC_FORMAT/CALL audit_control.gen_run_id('2',var_subjob_id_1); 
 COMMIT; 
 var_run_id := * FROM #my_temp; 
 val_src_count := count(*) FROM stg_rpt.src_ndc_format ;
                                  
 EXECUTE 'INSERT INTO "'|| audit_db ||'"."'|| audit_schema ||'"."'|| audit_job_validation_results_table ||'"(SUBJOB_ID,RULE_ID,TABLE_NAME,BATCH_RUNDATE,JOB_RUNID,SRC_COUNT,TGT_COUNT,TEST_RESULT,COMMENTS,RUN_ID) SELECT '|| var_subjob_id_1 ||' as SUBJOB_ID ,''2'' as RULE_ID,''DIM_NDC_FORMAT'' as TABLE_NAME, current_date as BATCH_RUNDATE,'|| var_run_id ||' as JOB_RUNID, '||val_src_count||' as SRC_COUNT, '||var_row_count||' as TGT_COUNT, case when '||val_src_count||' = '||var_row_count||' then ''Pass'' else ''Fail'' end as TEST_RESULT, case when '||val_src_count||' = '||var_row_count||' then ''SRC & TGT count matches'' else ''SRC & TGT count does not match'' end as COMMENTS,'''||run_id||''' as RUN_ID '; 
 COMMIT; 
 /ADD DEFAULT DIM_NDC_FORMAT/ /* EXECUTE 'INSERT INTO DW_RPT.DIM_NDC_FORMAT (NDC_FORMAT_CD_ID,VALUE_TXT,CRT_DT) SELECT ''9999'',''NONE'',current_date'; 
 COMMIT; 
 
 EXCEPTION WHEN others THEN EXECUTE 'CALL "'||db||'"."'||sc||'".sproc_audit_log('''||audit_db||''','''||audit_schema||''','''||ad||''','''||run_id||''',''DIM_NDC_FORMAT'',''1'',''STATUS'',''0'','''||batch_date||''','''||start_time||''','''||end_time||''')'; 
 COMMIT;  */
 END;
$$



redshift_cluster_name = secret['cluster_name']
redshift_db_name = secret['database']
redshift_db_user_name = secret['username']


--Initialize Redshift Data API client
redshift_client = boto3.client('redshift-data', region_name=region_name)


--Define and execute Redshift query---

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



**********************************************************************************************


Import sys
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



**************************************
"pull_generic_job.py"

import boto3
import json
import os
import time
import logging
import sys
from datetime import datetime
import urllib.parse
from boto3.dynamodb.conditions import Key, Attr

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

class RedshiftMetadata:
    error_msg = ''

    def _init_(self, cred):
        redshift_cred = json.loads(cred)
        self.redshift_cluster = redshift_cred['cluster_name']
        self.redshift_db = redshift_cred['database']
        self.redshift_user = redshift_cred['username']
        self.__redshift_client = boto3.client('redshift-data')

    def __get_response_dec(self, response_id):
        time.sleep(5)
        response_dec = self.__redshift_client.describe_statement(Id=response_id)
        logger.info(f"query State:{response_dec['Status']}")
        while response_dec['Status'] == "STARTED" or response_dec['Status'] == "PICKED" or response_dec['Status'] == "SUBMITTED":
            time.sleep(3)
            response_dec = self.__redshift_client.describe_statement(Id=response_id)
        logger.info(f"Status of describe statement API :{response_dec['Status']}")
        if response_dec['Status'] == "FINISHED":
            return True
        else:
            self.error_msg = response_dec['Error']
            return False
            
    def __get_result(self, response):
        redshift_res = []
        response_id = response['Id']
        if self.__get_response_dec(response_id):
            response_get = self.__redshift_client.get_statement_result(Id=response['Id'])
            if len(response_get['Records']) > 0:
                columns = [c['label'] for c in response_get['ColumnMetadata']]
                redshift_result = response_get['Records']
                for record in redshift_result:
                    param_dict = {}
                    for i in range(len(columns)):
                        param_dict[columns[i]] = record[i].get('longValue') or record[i].get('stringValue')
                    redshift_res.append(param_dict)
            else:
                logger.error('\n\nquery execution failed')
        return redshift_res

    def execute_only_query(self, query):
        logger.info(f'Query :{query}')
        response = self.__redshift_client.execute_statement(
            ClusterIdentifier=self.redshift_cluster,
            Database=self.redshift_db,
            DbUser=self.redshift_user,
            Sql=query)
        return self.__get_response_dec(response['Id'])

   def lambda_handler(event, context):
				start = time.time()
				dt_start = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
				global logger
				logger = CommonLogger(logging.INFO).get_logger()
				logger.info("inside lambda handler
	
	
	













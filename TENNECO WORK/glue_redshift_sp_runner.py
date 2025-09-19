import sys
import pg8000
import boto3
import json
from awsglue.utils import getResolvedOptions

# Get arguments from Glue job parameters
args = getResolvedOptions(sys.argv, ['secret_name', 'region_name', 'procedure_name'])

# Step 1: Retrieve Redshift credentials from AWS Secrets Manager
def get_redshift_credentials(secret_name, region_name):
    client = boto3.client('secretsmanager', region_name=region_name)
    get_secret_value_response = client.get_secret_value(SecretId=secret_name)
    secret = get_secret_value_response['SecretString']
    return json.loads(secret)

# Step 2: Connect to Redshift and execute stored procedure
def call_stored_procedure(credentials, procedure_name):
    try:
        conn = pg8000.connect(
            user=credentials['username'],
            password=credentials['password'],
            host=credentials['host'],
            port=int(credentials['port']),
            database=credentials['dbname']
        )

        cursor = conn.cursor()
        cursor.execute(f"CALL {procedure_name}();")
        conn.commit()
        print(f"Stored procedure '{procedure_name}' executed successfully.")

    except Exception as e:
        print(f"Error executing stored procedure: {e}")

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

# Main execution
if __name__ == "__main__":
    creds = get_redshift_credentials(args['secret_name'], args['region_name'])
    call_stored_procedure(creds, args['procedure_name'])
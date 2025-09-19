import sys
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col, upper, current_timestamp

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

# Initialize Spark/Glue contexts
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# -----------------------------
# Step 1: Read CSV from S3
# -----------------------------
input_path = "s3://shjo-sap-erp-data/15/customer.csv"

df = spark.read \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .csv(input_path)

print("Input schema:")
df.printSchema()

# -----------------------------
# Step 2: Transformations
# -----------------------------
# Example transformations:
# 1. Remove rows with null CustomerID
# 2. Uppercase the customer_name
# 3. Add a load timestamp column

df_transformed = (
    df.filter(col("CustomerID").isNotNull())
      .withColumn("FirstName", upper(col("FirstName")))
      .withColumn("load_ts", current_timestamp())
)

# -----------------------------
# Step 3: Write Output as CSV
# -----------------------------
output_path = "s3://shjo-sap-erp-data/15/output.csv"

# Write to a single CSV file
(df_transformed.coalesce(1)
 .write.mode("overwrite")
 .option("header", "true")
 .csv(output_path))

print(f"Transformed file written to {output_path}")

# Commit job
job.commit()
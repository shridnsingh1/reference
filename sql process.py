import os
import re

# Directory where your .sql or .txt files are stored
folder_path = "C:\\jkk\python"


# Regex to extract table names from FROM, JOIN, INTO, UPDATE
table_regex = re.compile(
    r"\bFROM\s+([^\s;]+)|\bJOIN\s+([^\s;]+)|\bUPDATE\s+([^\s;]+)", re.IGNORECASE
)

# Go through all text files in the folder
for filename in os.listdir(folder_path):
    if filename.endswith(".sql") or filename.endswith(".txt"):
        file_path = os.path.join(folder_path, filename)
        with open(file_path, "r", encoding="utf-8") as file:
            lines = file.readlines()

        # Remove lines starting with '--' (SQL comments)
        cleaned_sql = "\n".join(
            line for line in lines if not line.strip().startswith("--")
        )

        # Extract table names using regex
        matches = table_regex.findall(cleaned_sql)

        # Flatten the tuple matches and filter out empty strings
        tables = {table for match in matches for table in match if table}

        print(f"File: {filename}")
        print("Tables found:", tables)
        print("-" * 40)

import re
import os
from pathlib import Path
import pandas as pd


def clean_table_name(name: str) -> str:
    """Remove quotes and normalize schema.table names."""
    return name.replace('"', "").strip()


def extract_procedure_name(sql_text: str) -> str:
    """Find the procedure name after CREATE OR REPLACE PROCEDURE."""
    match = re.search(
        r"CREATE\s+OR\s+REPLACE\s+PROCEDURE\s+([a-zA-Z0-9_.\"]+)",
        sql_text,
        re.IGNORECASE,
    )
    if match:
        return clean_table_name(match.group(1))
    return "UNKNOWN_PROCEDURE"


def extract_tables(sql_text: str):
    """Extract source and target tables from SQL text."""
    source_tables = set()
    target_tables = set()

    # Source tables (after CREATE TEMPORARY TABLE ... FROM ...)
    temp_table_pattern = re.compile(
        r"CREATE\s+TEMPORARY\s+TABLE\s+#?\w+.*?FROM\s+([a-zA-Z0-9_\"\.]+)",
        re.IGNORECASE | re.DOTALL,
    )
    for match in temp_table_pattern.findall(sql_text):
        source_tables.add(clean_table_name(match))

    # Target tables (CREATE TABLE IF NOT EXISTS ...)
    create_table_pattern = re.compile(
        r"CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+([a-zA-Z0-9_\"\.]+)",
        re.IGNORECASE,
    )
    for match in create_table_pattern.findall(sql_text):
        target_tables.add(clean_table_name(match))

    # Target tables (INSERT INTO ...)
    insert_into_pattern = re.compile(
        r"INSERT\s+INTO\s+([a-zA-Z0-9_\"\.]+)",
        re.IGNORECASE,
    )
    for match in insert_into_pattern.findall(sql_text):
        target_tables.add(clean_table_name(match))

    return list(source_tables), list(target_tables)


def process_sql_files(folder_path: str, output_file: str):
    """Process all .sql files in the given folder and export results to Excel/CSV."""
    folder = Path(folder_path)
    results = []

    for file in folder.glob("*.sql"):
        with open(file, "r", encoding="utf-8") as f:
            sql_content = f.read()

        proc_name = extract_procedure_name(sql_content)
        sources, targets = extract_tables(sql_content)

        if not sources and not targets:
            results.append(
                {
                    "File": file.name,
                    "Procedure": proc_name,
                    "SourceTable": None,
                    "TargetTable": None,
                }
            )
        else:
            for s in sources or [None]:
                for t in targets or [None]:
                    results.append(
                        {
                            "File": file.name,
                            "Procedure": proc_name,
                            "SourceTable": s,
                            "TargetTable": t,
                        }
                    )

    # Save results to Excel or CSV
    df = pd.DataFrame(results)
    if output_file.endswith(".csv"):
        df.to_csv(output_file, index=False)
    else:
        df.to_excel(output_file, index=False)

    print(f"✅ Results exported to {output_file}")


if __name__ == "__main__":
    folder_path = (
        r"C:\Shailendra\TENNECO WORK\SQLFILES"  # 👈 replace with your folder path
    )
    output_file = r"C:\Shailendra\TENNECO WORK\sql_summary.xlsx"  # can also be .csv

    process_sql_files(folder_path, output_file)

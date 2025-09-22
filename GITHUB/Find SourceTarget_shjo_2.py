import re
import csv
from pathlib import Path


def clean_sql(sql_text: str) -> str:
    """Remove inline SQL comments starting with --"""
    return re.sub(r"--.*", "", sql_text)


def extract_target_table(sql_text: str):
    """Extract target table only from CREATE TABLE IF NOT EXISTS"""
    sql_text = clean_sql(sql_text)
    match = re.search(
        r'CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+([a-zA-Z0-9_".]+)',
        sql_text,
        re.IGNORECASE,
    )
    return match.group(1) if match else None


def extract_source_table(sql_text: str):
    """Extract all source tables inside CREATE TEMPORARY TABLE #... blocks (handles UNION)."""
    sql_text = clean_sql(sql_text)

    # Find the block starting from CREATE TEMPORARY TABLE ... up to the semicolon
    temp_block = re.search(
        r"CREATE\s+TEMPORARY\s+TABLE\s+#\w+.*?;", sql_text, re.IGNORECASE | re.DOTALL
    )
    if not temp_block:
        return None

    block_text = temp_block.group(0)

    # Find all tables after FROM inside this block (including UNION cases)
    matches = re.findall(r'from\s+([a-zA-Z0-9_".]+)', block_text, re.IGNORECASE)

    # Deduplicate & return
    return list(set(matches)) if matches else None


def process_sql_directory(directory: str, output_file: str):
    """Process all .sql files in a directory and write results to CSV"""
    results = []
    path = Path(directory)
    for file_path in path.glob("*.sql"):
        sql_text = file_path.read_text(encoding="utf-8", errors="ignore")
        target = extract_target_table(sql_text)
        source = extract_source_table(sql_text)
        results.append([file_path.name, target, source])

    # Write to CSV
    with open(output_file, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["File", "Target_Table", "Source_Table"])  # header
        writer.writerows(results)

    print(f"✅ Results saved to {output_file}")


# Example usage
directory = r"C:\Shailendra\TENNECO WORK\SQLFILES"
output_file = r"C:\Shailendra\TENNECO WORK\SQL_Output.csv"
process_sql_directory(directory, output_file)

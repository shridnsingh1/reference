import re


def extract_tables(sql_text: str):
    """
    Extract source and target tables from PL/pgSQL procedure text.
    """

    target_tables = set()
    source_tables = set()

    # --- Target Tables ---
    # CREATE TABLE IF NOT EXISTS <schema.table>
    target_tables.update(
        re.findall(
            r"CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+([a-zA-Z0-9_.#]+)",
            sql_text,
            flags=re.IGNORECASE,
        )
    )

    # INSERT INTO <schema.table>
    target_tables.update(
        re.findall(r"INSERT\s+INTO\s+([a-zA-Z0-9_.#]+)", sql_text, flags=re.IGNORECASE)
    )

    # --- Source Tables ---
    # CREATE TEMPORARY TABLE #temp ... AS
    source_tables.update(
        re.findall(
            r"CREATE\s+TEMPORARY\s+TABLE\s+(#[a-zA-Z0-9_]+)",
            sql_text,
            flags=re.IGNORECASE,
        )
    )

    # FROM <schema.table>
    source_tables.update(
        re.findall(r"FROM\s+\"?([a-zA-Z0-9_.#]+)\"?", sql_text, flags=re.IGNORECASE)
    )

    return list(source_tables), list(target_tables)


if __name__ == "__main__":
    # Example: read from a SQL file
    with open("C:/Shailendra/TENNECO WORK/SP.sql", "r", encoding="utf-8") as f:
        sql_content = f.read()

    sources, targets = extract_tables(sql_content)

    print("✅ Source Tables Found:")
    for s in sources:
        print("  -", s)

    print("\n✅ Target Tables Found:")
    for t in targets:
        print("  -", t)

import os


def search_string_in_files(directory, search_string):
    """Search for a string in all files under a directory."""
    results = {}

    # Walk through all subdirectories and files
    for root, _, files in os.walk(directory):
        for file in files:
            file_path = os.path.join(root, file)

            try:
                with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                    for line_num, line in enumerate(f, start=1):
                        if search_string.lower() in line.lower():
                            if file_path not in results:
                                results[file_path] = []
                            results[file_path].append((line_num, line.strip()))
            except Exception as e:
                print(f"⚠️ Could not read file {file_path}: {e}")

    return results


if __name__ == "__main__":
    directory = r"C:\path\to\your\dir"  # 🔹 Change this path
    search_string = "union"  # 🔹 Change your keyword

    matches = search_string_in_files(directory, search_string)

    if matches:
        print(f"🔍 Found '{search_string}' in {len(matches)} file(s):\n")
        for file, occurrences in matches.items():
            print(f"\n📂 File: {file}")
            for line_num, line_text in occurrences:
                print(f"   Line {line_num}: {line_text}")
    else:
        print(f"❌ No matches found for '{search_string}'")

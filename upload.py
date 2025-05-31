#!/usr/bin/env python3

import os
import sys
from pathlib import Path
import argparse
from internetarchive import upload

# Load product name from central source
product_name_file = Path("product_name.txt")
if not product_name_file.exists():
    print("Error: 'product_name.txt' not found", file=sys.stderr)
    sys.exit(1)
try:
    PRODUCT_NAME = product_name_file.read_text().strip()
except Exception as e:
    print(f"Error: failed to read 'product_name.txt': {e}", file=sys.stderr)
    sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Upload dist files to archive.org")
    parser.add_argument("--identifier", required=True, help="Archive.org identifier for the upload")
    parser.add_argument("--dist-dir", default="dist", help="Directory containing ISO files to upload")
    parser.add_argument("--config", default="ia.ini", help="Path to ia.ini config file")
    args = parser.parse_args()

    if not args.identifier:
        print("Error: --identifier is required", file=sys.stderr)
        sys.exit(1)

    dist_path = Path(args.dist_dir)
    if not dist_path.exists() or not dist_path.is_dir():
        print(f"Error: dist directory '{args.dist_dir}' does not exist or is not a directory", file=sys.stderr)
        sys.exit(1)

    iso_files = list(dist_path.glob("*.iso"))
    if not iso_files:
        print(f"Error: No .iso files found in '{args.dist_dir}'", file=sys.stderr)
        sys.exit(1)

    other_files = [f for f in dist_path.iterdir() if f.is_file() and f.suffix.lower() != ".iso"]
    if other_files:
        print("Error: Non-ISO files found in dist directory:", file=sys.stderr)
        for f in other_files:
            print(f"  {f.name}", file=sys.stderr)
        sys.exit(1)

    config_path = Path(args.config)
    if config_path.exists():
        os.environ["IA_CONFIG_FILE"] = str(config_path.resolve())

    metadata = {
        "title": PRODUCT_NAME,
        "description": "A plug-and-play Debian Live ISO with Ollama preinstalled — bootable from USB, air-gapped by design, and ready to run large language models offline.",
        "creator": "vedmakk",
        "mediatype": "software",
        "subject": "ollama; debian-live; air-gapped; llm",
        "licenseurl": "https://creativecommons.org/publicdomain/mark/1.0/"
    }

    print(f"Uploading files from '{args.dist_dir}' to archive.org with identifier '{args.identifier}'...")
    try:
        response = upload(args.identifier, str(dist_path) + "/", metadata=metadata, verbose=True, retries=10, retries_sleep=30)
        print("Upload response:", response)

        if response[0].status_code != 200:
            print("Error: Upload failed", file=sys.stderr)
            sys.exit(1)

        print("✅ Upload successful")
    except Exception as e:
        print("Error during upload:", e, file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()

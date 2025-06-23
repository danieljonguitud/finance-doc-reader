#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # The return value of a pipeline is the status of the last command to exit with a non-zero status

# --- Sanity Checks ---
if [ -z "$INPUT_S3_BUCKET" ]; then
  echo "Error: INPUT_S3_BUCKET environment variable not set."
  exit 1
fi

if [ -z "$OUTPUT_S3_URI_PREFIX" ]; then
  echo "Error: OUTPUT_S3_URI_PREFIX environment variable not set."
  exit 1
fi

# --- Setup Local Environment ---
echo "--- Setting up local environment ---"
LOCAL_PROCESSING_DIR=$(mktemp -d)
LOCAL_OUTPUT_DIR="$LOCAL_PROCESSING_DIR/output"
mkdir -p "$LOCAL_OUTPUT_DIR"

echo "Local processing directory: $LOCAL_PROCESSING_DIR"
echo "Local output directory: $LOCAL_OUTPUT_DIR"

# --- Download All PDF Files from S3 ---
echo "--- Downloading all PDF files from S3 bucket ---"
echo "Source bucket: s3://$INPUT_S3_BUCKET/"
echo "Destination: $LOCAL_PROCESSING_DIR"
aws s3 sync "s3://$INPUT_S3_BUCKET/" "$LOCAL_PROCESSING_DIR" --exclude "*" --include "*.pdf"

# Count PDFs found
PDF_COUNT=$(find "$LOCAL_PROCESSING_DIR" -name "*.pdf" -type f | wc -l)
if [ "$PDF_COUNT" -eq 0 ]; then
  echo "Error: No PDF files found in S3 bucket."
  exit 1
fi
echo "Download complete. Found $PDF_COUNT PDF files to process."

# --- Run Marker Conversion ---
echo "--- Starting Marker Conversion ---"
# marker_cli expects the output directory to exist.
# It will create a markdown file named <input_filename_without_extension>.md inside the output directory.
marker "$LOCAL_PROCESSING_DIR" --output_dir "$LOCAL_OUTPUT_DIR" --workers 1 --disable_image_extraction

# --- Find and Upload All Markdown Files ---
echo "--- Finding and uploading all markdown files ---"

# Find all .md files recursively in output directory
MD_FILES_FOUND=0
find "$LOCAL_OUTPUT_DIR" -name "*.md" -type f | while read -r md_file; do
  # Extract filename without path and extension for S3 key
  base_name=$(basename "$md_file" .md)
  s3_destination="$OUTPUT_S3_URI_PREFIX/${base_name}.md"
  
  echo "Uploading: $md_file -> $s3_destination"
  aws s3 cp "$md_file" "$s3_destination"
  MD_FILES_FOUND=$((MD_FILES_FOUND + 1))
done

# Verify at least one file was processed
MD_COUNT=$(find "$LOCAL_OUTPUT_DIR" -name "*.md" -type f | wc -l)
if [ "$MD_COUNT" -eq 0 ]; then
  echo "--- Conversion Failed ---"
  echo "No markdown files were generated."
  echo "Contents of $LOCAL_OUTPUT_DIR:"
  ls -lA "$LOCAL_OUTPUT_DIR"
  exit 1
fi

echo "Successfully uploaded $MD_COUNT markdown files to S3."

# --- Cleanup ---
echo "--- Cleaning up local directory ---"
rm -rf "$LOCAL_PROCESSING_DIR"

echo "--- Script Finished ---"

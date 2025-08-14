#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # The return value of a pipeline is the status of the last command to exit with a non-zero status

# --- Sanity Checks ---
if [ -z "$S3_URI" ]; then
  echo "Error: S3_URI environment variable not set."
  exit 1
fi

# Validate S3_URI format
if [[ ! "$S3_URI" =~ ^s3:// ]]; then
  echo "Error: S3_URI must start with s3://"
  echo "Provided: $S3_URI"
  exit 1
fi

# --- Parse S3_URI ---
echo "--- Parsing S3_URI ---"
echo "S3_URI: $S3_URI"

# Extract bucket name (everything between s3:// and first /)
S3_BUCKET=$(echo "$S3_URI" | sed 's|s3://||' | cut -d'/' -f1)

# Extract full S3 key (everything after bucket/)
S3_KEY=$(echo "$S3_URI" | sed 's|s3://[^/]*/||')

# Extract folder path (everything except the filename)
FOLDER_PATH=$(dirname "$S3_KEY")

echo "S3 Bucket: $S3_BUCKET"
echo "S3 Key: $S3_KEY"
echo "Folder Path: $FOLDER_PATH"

# --- Setup Local Environment ---
echo "--- Setting up local environment ---"
LOCAL_PROCESSING_DIR=$(mktemp -d)
LOCAL_OUTPUT_DIR="$LOCAL_PROCESSING_DIR/output"
mkdir -p "$LOCAL_OUTPUT_DIR"

# Create timestamp for this processing run
PROCESSING_TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
echo "Processing timestamp: $PROCESSING_TIMESTAMP"

echo "Local processing directory: $LOCAL_PROCESSING_DIR"
echo "Local output directory: $LOCAL_OUTPUT_DIR"

# --- Download All PDF Files from S3 Folder ---
echo "--- Downloading all PDF files from S3 folder ---"
echo "Source folder: s3://$S3_BUCKET/$FOLDER_PATH/"
echo "Destination: $LOCAL_PROCESSING_DIR"
aws s3 sync "s3://$S3_BUCKET/$FOLDER_PATH/" "$LOCAL_PROCESSING_DIR" --exclude "*" --include "*.pdf"

# Count PDFs found
PDF_COUNT=$(find "$LOCAL_PROCESSING_DIR" -name "*.pdf" -type f | wc -l)
if [ "$PDF_COUNT" -eq 0 ]; then
  echo "Error: No PDF files found in S3 folder: s3://$S3_BUCKET/$FOLDER_PATH/"
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
FAILED_UPLOADS=0

find "$LOCAL_OUTPUT_DIR" -name "*.md" -type f | while read -r md_file; do
  # Extract just the filename for naming
  base_name=$(basename "$md_file" .md)
  
  # Create S3 path in same folder as source PDFs
  s3_destination="s3://$S3_BUCKET/$FOLDER_PATH/${base_name}.md"
  
  echo "Uploading: $md_file -> $s3_destination"
  
  # Upload with error handling
  if aws s3 cp "$md_file" "$s3_destination"; then
    echo "✓ Successfully uploaded: ${base_name}.md"
    MD_FILES_FOUND=$((MD_FILES_FOUND + 1))
  else
    echo "✗ Failed to upload: $md_file"
    FAILED_UPLOADS=$((FAILED_UPLOADS + 1))
  fi
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

# Check for upload failures
if [ "$FAILED_UPLOADS" -gt 0 ]; then
  echo "⚠️  Warning: $FAILED_UPLOADS file(s) failed to upload to S3"
fi

echo "Successfully uploaded $MD_FILES_FOUND markdown files to S3 folder: s3://$S3_BUCKET/$FOLDER_PATH/"

# --- Cleanup ---
echo "--- Cleaning up local directory ---"
rm -rf "$LOCAL_PROCESSING_DIR"

echo "--- Script Finished ---"

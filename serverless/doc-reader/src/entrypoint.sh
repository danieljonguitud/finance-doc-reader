#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # The return value of a pipeline is the status of the last command to exit with a non-zero status

# --- Sanity Checks ---
if [ -z "$INPUT_S3_URI" ]; then
  echo "Error: INPUT_S3_URI environment variable not set."
  exit 1
fi

if [ -z "$OUTPUT_S3_URI_PREFIX" ]; then
  echo "Error: OUTPUT_S3_URI_PREFIX environment variable not set."
  exit 1
fi

# --- Setup Local Environment ---
echo "--- Setting up local environment ---"
LOCAL_PROCESSING_DIR=$(mktemp -d)
LOCAL_INPUT_FILE="$LOCAL_PROCESSING_DIR/$(basename "$INPUT_S3_URI")"
LOCAL_OUTPUT_DIR="$LOCAL_PROCESSING_DIR/output"
mkdir -p "$LOCAL_OUTPUT_DIR"

echo "Local processing directory: $LOCAL_PROCESSING_DIR"
echo "Local input file path: $LOCAL_INPUT_FILE"
echo "Local output directory: $LOCAL_OUTPUT_DIR"

# --- Download Input File from S3 ---
echo "--- Downloading input file from S3 ---"
echo "Source: $INPUT_S3_URI"
echo "Destination: $LOCAL_INPUT_FILE"
aws s3 cp "$INPUT_S3_URI" "$LOCAL_INPUT_FILE"
if [ ! -f "$LOCAL_INPUT_FILE" ]; then
  echo "Error: Failed to download file from S3."
  exit 1
fi
echo "Download complete."

# --- Run Marker Conversion ---
echo "--- Starting Marker Conversion ---"
# marker_cli expects the output directory to exist.
# It will create a markdown file named <input_filename_without_extension>.md inside the output directory.
marker "$LOCAL_PROCESSING_DIR" --output_dir "$LOCAL_OUTPUT_DIR" --workers 0 --disable_image_extraction

# --- Verify and Upload Output ---
echo "--- Verifying and Uploading Output ---"
INPUT_BASENAME=$(basename "$LOCAL_INPUT_FILE")
INPUT_FILENAME_NO_EXT="${INPUT_BASENAME%.*}"
EXPECTED_OUTPUT_MD="$LOCAL_OUTPUT_DIR/$INPUT_FILENAME_NO_EXT.md"

if [ -f "$EXPECTED_OUTPUT_MD" ]; then
  echo "Conversion Successful. Found output file: $EXPECTED_OUTPUT_MD"
  
  # Construct the destination S3 URI
  OUTPUT_S3_URI="$OUTPUT_S3_URI_PREFIX/$INPUT_FILENAME_NO_EXT.md"
  
  echo "Uploading to S3..."
  echo "Source: $EXPECTED_OUTPUT_MD"
  echo "Destination: $OUTPUT_S3_URI"
  aws s3 cp "$EXPECTED_OUTPUT_MD" "$OUTPUT_S3_URI"
  echo "Upload complete."
else
  echo "--- Conversion Failed ---"
  echo "Expected output file $EXPECTED_OUTPUT_MD was not found."
  # List contents of output dir for debugging
  echo "Contents of $LOCAL_OUTPUT_DIR:"
  ls -lA "$LOCAL_OUTPUT_DIR"
  exit 1
fi

# --- Cleanup ---
echo "--- Cleaning up local directory ---"
rm -rf "$LOCAL_PROCESSING_DIR"

echo "--- Script Finished ---"

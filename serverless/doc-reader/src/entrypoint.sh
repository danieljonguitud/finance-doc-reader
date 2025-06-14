#!/bin/sh
set -e # Exit immediately if a command exits with a non-zero status.

# --- Sanity Checks ---
if [ -z "$INPUT_FILE_PATH" ]; then
  echo "Error: INPUT_FILE_PATH environment variable not set."
  echo "Usage: Set INPUT_FILE_PATH and OUTPUT_DIR_PATH environment variables when running the container."
  exit 1
fi

if [ -z "$OUTPUT_DIR_PATH" ]; then
  echo "Error: OUTPUT_DIR_PATH environment variable not set."
  echo "Usage: Set INPUT_FILE_PATH and OUTPUT_DIR_PATH environment variables when running the container."
  exit 1
fi

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR_PATH"

echo "--- Starting Marker Conversion ---"
echo "Input file: $INPUT_FILE_PATH"
echo "Output directory: $OUTPUT_DIR_PATH"

# Run marker_cli
# --workers 0 is often recommended for CPU processing to avoid overhead or issues with multiprocessing in some environments.
# Adjust --batch_multiplier and --max_pages as needed for your testing/performance.
# marker_cli will create a markdown file named <input_filename_without_extension>.md inside the OUTPUT_DIR_PATH.
# marker "$INPUT_FILE_PATH" "$OUTPUT_DIR_PATH" --workers 0 --batch_multiplier 1 # --max_pages 5 (optional: for faster testing)
marker "$INPUT_FILE_PATH" --output_dir "$OUTPUT_DIR_PATH" --workers 0 --disable_image_extraction # Removed --batch_multiplier 1 since it's not supported in multiple files


# Extract the base name of the input file (e.g., "document.pdf" -> "document")
INPUT_BASENAME=$(basename "$INPUT_FILE_PATH")
INPUT_FILENAME_NO_EXT="${INPUT_BASENAME%.*}"
EXPECTED_OUTPUT_MD="$OUTPUT_DIR_PATH/$INPUT_FILENAME_NO_EXT.md"

if [ -f "$EXPECTED_OUTPUT_MD" ]; then
  echo "--- Conversion Successful ---"
  echo "Markdown output saved to: $EXPECTED_OUTPUT_MD"
else
  echo "--- Conversion Failed ---"
  echo "Expected output file $EXPECTED_OUTPUT_MD was not found."
  # List contents of output dir for debugging
  echo "Contents of $OUTPUT_DIR_PATH:"
  ls -lA "$OUTPUT_DIR_PATH"
  exit 1
fi

echo "--- Script Finished ---"

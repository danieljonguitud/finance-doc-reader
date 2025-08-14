# Use a Python base image. Slim versions are smaller.
# Check marker documentation for compatible Python versions if specific.
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies that might be needed by PyTorch or other libraries
# libgomp1 is often needed for OpenMP support in PyTorch CPU operations
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Set environment variable for model caching location within the container
# This ensures models are downloaded to a predictable path.
ENV XDG_CACHE_HOME=/opt/marker_cache
RUN mkdir -p ${XDG_CACHE_HOME}

# Copy Python dependencies file and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-download marker models during build by running marker on a dummy PDF
RUN python -c "import os; pdf_content = b'%PDF-1.4\\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj 3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]>>endobj xref\\n0 4\\n0000000000 65535 f\\n0000000009 00000 n\\n0000000058 00000 n\\n0000000115 00000 n\\ntrailer<</Size 4/Root 1 0 R>>\\nstartxref\\n175\\n%%EOF'; open('/tmp/dummy.pdf', 'wb').write(pdf_content)" && \
    mkdir -p /tmp/output && \
    marker /tmp --output_dir /tmp/output --workers 1 --disable_image_extraction || echo "Models downloaded successfully" && \
    rm -rf /tmp/dummy.pdf /tmp/output

# Copy the Python entrypoint script into the container
COPY main.py .
RUN chmod +x main.py

# Set the Python entrypoint
ENTRYPOINT ["python", "main.py"]

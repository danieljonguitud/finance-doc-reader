# Use a Python base image. Slim versions are smaller.
# Check marker documentation for compatible Python versions if specific.
FROM python:3.10-slim

# Set working directory
WORKDIR /app

ENV INPUT_FILE_PATH=/inputs
ENV OUTPUT_DIR_PATH=/outputs

# Install system dependencies that might be needed by PyTorch or other libraries
# libgomp1 is often needed for OpenMP support in PyTorch CPU operations
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Set environment variable for model caching location within the container
# This ensures models are downloaded to a predictable path.
ENV XDG_CACHE_HOME=/opt/marker_cache
RUN mkdir -p ${XDG_CACHE_HOME}

# Install marker and its CPU dependencies (onnxruntime)
# Using marker-splitter as it's the recommended package.
# Pin versions if you need stability.
RUN pip install --no-cache-dir marker-pdf[full] torch torchvision torchaudio

# Copy the entrypoint script into the container
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["./entrypoint.sh"]

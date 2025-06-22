#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # The return value of a pipeline is the status of the last command to exit with a non-zero status

# A script to build the doc-reader Docker image and push it to the ECR repository
# created by the CloudFormation/SAM stack.
#
# Prerequisites:
# - AWS CLI installed and configured.
# - Docker installed and running.
# - The CloudFormation stack must be successfully deployed.
#
# Usage:
# ./deploy-container.sh <cloudformation-stack-name> <aws-region>
#
# Example from the project root:
# ./serverless/doc-reader/deploy-container.sh doc-reader-infra us-east-1

# --- Check for required commands ---
command -v aws >/dev/null 2>&1 || { echo >&2 "Error: AWS CLI is required but not installed. Aborting."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo >&2 "Error: Docker is required but not installed. Aborting."; exit 1; }

# --- Configuration from command-line arguments ---
STACK_NAME=$1
AWS_REGION=$2

if [ -z "$STACK_NAME" ] || [ -z "$AWS_REGION" ]; then
  echo "Usage: ./deploy-container.sh <cloudformation-stack-name> <aws-region>"
  echo "Example: ./deploy-container.sh doc-reader-infra us-east-1"
  exit 1
fi

echo "--- Configuration ---"
echo "CloudFormation Stack Name: $STACK_NAME"
echo "AWS Region:              $AWS_REGION"
echo "---------------------"

# --- 1. Get ECR Repository URI from CloudFormation Stack ---
echo
echo "STEP 1: Fetching ECR repository URI from stack '$STACK_NAME'..."
ECR_REPO_URI=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$AWS_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='EcrRepositoryUri'].OutputValue" \
  --output text)

if [ -z "$ECR_REPO_URI" ]; then
  echo "Error: Could not find 'EcrRepositoryUri' in the outputs of stack '$STACK_NAME'."
  echo "Please ensure the stack has been deployed successfully and the output exists."
  exit 1
fi

echo "Successfully found ECR Repository URI: $ECR_REPO_URI"

# --- 2. Authenticate Docker to ECR ---
echo
echo "STEP 2: Authenticating Docker with ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REPO_URI"
echo "Docker authentication successful."

# --- 3. Build, Tag, and Push the Docker Image ---
# The Dockerfile is expected to be in the 'src' subdirectory relative to this script's location.
DOCKER_CONTEXT_PATH="$(dirname "$0")/src"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${ECR_REPO_URI}:${IMAGE_TAG}"

if [ ! -f "$DOCKER_CONTEXT_PATH/Dockerfile" ]; then
    echo "Error: Dockerfile not found at '$DOCKER_CONTEXT_PATH/Dockerfile'"
    exit 1
fi

echo
echo "STEP 3: Building and pushing Docker image..."
echo "Context path: $DOCKER_CONTEXT_PATH"
echo "Image name:   $FULL_IMAGE_NAME"

# Build the image and tag it in one step
docker build -t "$FULL_IMAGE_NAME" "$DOCKER_CONTEXT_PATH"

echo
echo "Pushing image to ECR..."
docker push "$FULL_IMAGE_NAME"

echo
echo "--- Success! ---"
echo "Image '$FULL_IMAGE_NAME' has been pushed to ECR."
echo "The Fargate Task Definition can now pull this image."

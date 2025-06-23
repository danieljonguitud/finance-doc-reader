#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # The return value of a pipeline is the status of the last command to exit with a non-zero status

# A script to manually trigger a Fargate task for testing purposes.
# It simulates how a Step Function would invoke the task.
#
# Prerequisites:
# - AWS CLI installed and configured.
# - The CloudFormation stack must be successfully deployed.
# - The container image must be pushed to ECR.
# - A test file must be uploaded to the input S3 bucket.
#
# Usage:
# ./test-fargate-task.sh <stack-name> <aws-region>
#
# Example from the project root:
# ./serverless/doc-reader/test-fargate-task.sh doc-reader-infra us-east-1

# --- Check for required commands ---
command -v aws >/dev/null 2>&1 || { echo >&2 "Error: AWS CLI is required but not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "Error: jq is required but not installed. Aborting."; exit 1; }

# --- Configuration from command-line arguments ---
STACK_NAME=$1
AWS_REGION=$2

if [ -z "$STACK_NAME" ] || [ -z "$AWS_REGION" ]; then
  echo "Usage: ./test-fargate-task.sh <stack-name> <aws-region>"
  echo "Example: ./test-fargate-task.sh doc-reader-infra us-east-1"
  exit 1
fi

echo "--- Configuration ---"
echo "CloudFormation Stack Name: $STACK_NAME"
echo "AWS Region:              $AWS_REGION"
echo "Processing:              All PDFs in input bucket"
echo "---------------------"

# --- 1. Get Required Values from CloudFormation Stack Outputs ---
echo
echo "STEP 1: Fetching resource names from stack '$STACK_NAME'..."
CLUSTER_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" --query "Stacks[0].Outputs[?OutputKey=='EcsClusterName'].OutputValue" --output text)
TASK_DEFINITION_ARN=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" --query "Stacks[0].Outputs[?OutputKey=='TaskDefinitionArn'].OutputValue" --output text)
INPUT_BUCKET=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" --query "Stacks[0].Outputs[?OutputKey=='InputBucketName'].OutputValue" --output text)
OUTPUT_BUCKET=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" --query "Stacks[0].Outputs[?OutputKey=='OutputBucketName'].OutputValue" --output text)

# Validate that we got all the values
if [ -z "$CLUSTER_NAME" ] || [ -z "$TASK_DEFINITION_ARN" ] || [ -z "$INPUT_BUCKET" ] || [ -z "$OUTPUT_BUCKET" ]; then
  echo "Error: Could not retrieve all required outputs from stack '$STACK_NAME'. Please check the stack status and outputs."
  exit 1
fi

echo "  -> Cluster Name:        $CLUSTER_NAME"
echo "  -> Task Definition ARN: $TASK_DEFINITION_ARN"
echo "  -> Input S3 Bucket:     $INPUT_BUCKET"
echo "  -> Output S3 Bucket:    $OUTPUT_BUCKET"

# --- 2. Get Network Configuration (Default VPC and Subnet) ---
echo
echo "STEP 2: Discovering network configuration from default VPC..."
VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters Name=isDefault,Values=true --query "Vpcs[0].VpcId" --output text)
if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo "Error: Could not find a default VPC in region $AWS_REGION."
    exit 1
fi
echo "  -> Found Default VPC: $VPC_ID"

SUBNET_ID=$(aws ec2 describe-subnets --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[0].SubnetId" --output text)
if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" == "None" ]; then
    echo "Error: Could not find any subnets in the default VPC."
    exit 1
fi
echo "  -> Using Subnet:      $SUBNET_ID"

# --- 3. Run the Fargate Task ---
echo
echo "STEP 3: Triggering Fargate task..."
OUTPUT_S3_PREFIX="s3://${OUTPUT_BUCKET}/test-run-output"

TASK_RUN_OUTPUT=$(aws ecs run-task \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --task-definition "$TASK_DEFINITION_ARN" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],assignPublicIp=ENABLED}" \
  --overrides '{
      "containerOverrides": [
        {
          "name": "doc-reader-local",
          "environment": [
            {
              "name": "INPUT_S3_BUCKET",
              "value": "'"$INPUT_BUCKET"'"
            },
            {
              "name": "OUTPUT_S3_URI_PREFIX",
              "value": "'"$OUTPUT_S3_PREFIX"'"
            }
          ]
        }
      ]
    }')

TASK_ARN=$(echo "$TASK_RUN_OUTPUT" | jq -r '.tasks[0].taskArn')
echo "  -> Task started successfully!"
echo "  -> Task ARN: $TASK_ARN"

# --- 4. Next Steps ---
echo
echo "--- What to do next ---"
echo "1. Monitor Logs: Check the container logs for progress and errors."
echo "   Go to CloudWatch -> Log Groups -> /ecs/doc-reader-local"
echo
echo "2. Check Output: Once the task is complete, check for the converted markdown file."
echo "   Run the following command:"
echo "   aws s3 ls ${OUTPUT_S3_PREFIX}/"
echo

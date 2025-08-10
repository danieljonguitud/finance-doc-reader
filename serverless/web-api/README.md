# Web API Service

A versioned REST API Gateway with direct S3 integration for uploading documents to the finance document reader system.

## Overview

This service provides a single endpoint `POST /v1/documents/` that allows clients to upload files directly to the S3 input bucket, which then triggers the existing document processing pipeline (doc-reader → llm-processor).

## Architecture

- **API Gateway**: REST API with versioning (v1)
- **Direct S3 Integration**: Files uploaded directly to S3 without Lambda
- **IAM Authentication**: Secure access using AWS IAM
- **CORS Support**: Cross-origin requests enabled

## Deployment

### Prerequisites

1. Deploy the `core-infra` stack first (provides S3 buckets)
2. Ensure you have AWS CLI and SAM CLI configured

### Deploy the Service

```bash
cd serverless/web-api
sam deploy --guided  # First time
sam deploy            # Subsequent deployments
```

## API Usage

### Endpoint

```
POST https://{api-id}.execute-api.{region}.amazonaws.com/prod/v1/documents/
```

### Authentication

The API uses AWS IAM authentication. You need to sign your requests using AWS Signature Version 4.

### Request Headers

- `Content-Type`: `application/pdf`, `application/octet-stream`, or `multipart/form-data`
- `x-amz-meta-filename`: The filename for the uploaded file (required)
- `x-amz-meta-template`: JSON template for processing instructions (optional)
- `Authorization`: AWS Signature V4 authorization header

### Request Body

Raw file content (binary data)

### Response

#### Success (200 OK)

```json
{
  "uploadId": "12345678-1234-1234-1234-123456789abc",
  "s3Key": "uploads/1672531200000-document.pdf",
  "bucket": "finance-doc-core-infra-input-bucket-123456789012-us-west-2",
  "status": "uploaded",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

#### Error Responses

```json
{
  "error": "Bad Request",
  "message": "Invalid file upload request"
}
```

## Example Usage

### Using cURL with AWS CLI

```bash
# Get API URL from stack outputs
API_URL=$(aws cloudformation describe-stacks --stack-name web-api-local --query 'Stacks[0].Outputs[?OutputKey==`DocumentsEndpoint`].OutputValue' --output text)

# Upload a file
curl -X POST "$API_URL" \
  -H "Content-Type: application/pdf" \
  -H "x-amz-meta-filename: test-document.pdf" \
  -H "x-amz-meta-template: {\"instructions\": \"extract financial data\"}" \
  --data-binary @path/to/document.pdf \
  --aws-sigv4 "aws:amz:us-west-2:execute-api"
```

### Using AWS SDK (JavaScript)

```javascript
import AWS from 'aws-sdk';

const apigateway = new AWS.APIGateway();
const endpoint = 'https://your-api-id.execute-api.us-west-2.amazonaws.com/prod/v1/documents/';

const uploadFile = async (fileBuffer, filename, template) => {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/pdf',
      'x-amz-meta-filename': filename,
      'x-amz-meta-template': JSON.stringify(template),
      'Authorization': 'AWS4-HMAC-SHA256 ...' // AWS Sig V4
    },
    body: fileBuffer
  });
  
  return await response.json();
};
```

## Monitoring

- **CloudWatch Logs**: `/aws/apigateway/web-api`
- **API Gateway Metrics**: Available in CloudWatch console
- **X-Ray Tracing**: Enabled for performance monitoring

## Integration with Processing Pipeline

Once a file is uploaded to S3:

1. **S3 Event**: Triggers existing EventBridge rules
2. **Document Reader**: Processes PDF to markdown
3. **LLM Processor**: Analyzes markdown content
4. **Results**: Stored in output S3 bucket

## Security

- AWS IAM authentication required
- S3 bucket access limited to uploads/ prefix
- API rate limiting and throttling enabled
- CloudWatch logging for audit trail

## Troubleshooting

### Common Issues

1. **403 Forbidden**: Check IAM permissions and AWS Signature V4
2. **400 Bad Request**: Ensure `x-amz-meta-filename` header is provided
3. **500 Internal Error**: Check CloudWatch logs for S3 access issues

### Logs

```bash
# View API Gateway logs
aws logs tail /aws/apigateway/web-api --follow

# Check stack events
aws cloudformation describe-stack-events --stack-name web-api-local
```
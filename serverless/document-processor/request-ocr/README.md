# Request OCR - Mistral OCR Lambda Function

A Go-based AWS Lambda function that replaces AWS Textract with Mistral OCR for PDF text extraction.

## Overview

This Lambda function processes PDF documents using the Mistral OCR API instead of AWS Textract. It's designed to integrate with the existing document processing pipeline while providing more flexible OCR capabilities.

## Architecture

- **Runtime**: Go 1.x
- **Memory**: 1024MB (configurable)
- **Timeout**: 5 minutes
- **Trigger**: Step Functions, API Gateway, or direct invocation
- **Storage**: Reads from S3 input bucket
- **API**: Mistral OCR API for text extraction

## Prerequisites

- AWS CLI configured
- SAM CLI installed
- Go 1.21+ installed
- Make utility

## Setup

### 1. Clone and Navigate
```bash
cd /serverless/document-processor/request-ocr/
```

### 2. Initialize Go Modules
```bash
make mod-download
```

### 3. Create Mistral API Key Secret
```bash
aws secretsmanager create-secret \
  --name mistral-api-key \
  --description "Mistral API key for OCR processing" \
  --secret-string "your-mistral-api-key-here"
```

### 4. Create Your Go Code
Create `main.go` with your Mistral OCR implementation:

```go
package main

import (
    "context"
    "encoding/json"
    "log"

    "github.com/aws/aws-lambda-go/events"
    "github.com/aws/aws-lambda-go/lambda"
)

type OCRRequest struct {
    Bucket string `json:"bucket"`
    Key    string `json:"key"`
}

type OCRResponse struct {
    Text   string `json:"text"`
    Status string `json:"status"`
}

func handler(ctx context.Context, request OCRRequest) (OCRResponse, error) {
    // Your Mistral OCR implementation here
    log.Printf("Processing OCR request for s3://%s/%s", request.Bucket, request.Key)
    
    // TODO: Implement Mistral OCR logic
    // 1. Download PDF from S3
    // 2. Call Mistral OCR API
    // 3. Return extracted text
    
    return OCRResponse{
        Text:   "Extracted text will go here",
        Status: "success",
    }, nil
}

func main() {
    lambda.Start(handler)
}
```

## Deployment

### Build and Deploy
```bash
# Build the function
make sam-build

# Deploy to AWS
make sam-deploy
```

### Manual Build (Alternative)
```bash
# Build binary
make build

# Create package
make package

# Deploy with SAM
sam deploy
```

## Configuration

### Environment Variables
- `LOG_LEVEL`: Logging level (INFO, DEBUG, ERROR)
- `MISTRAL_API_ENDPOINT`: Mistral API endpoint URL
- `MISTRAL_API_KEY_SECRET`: Secret name containing Mistral API key
- `INPUT_BUCKET`: S3 bucket for input files

### Parameters
You can override parameters during deployment:
```bash
sam deploy --parameter-overrides \
  ProjectName=my-ocr-function \
  MistralApiEndpoint=https://api.mistral.ai \
  MistralApiKeySecretName=my-mistral-key
```

## Testing

### Local Testing
```bash
# Start local API
make sam-local

# Test the endpoint
curl -X POST http://localhost:3000/ocr \
  -H "Content-Type: application/json" \
  -d '{"bucket":"my-bucket","key":"path/to/file.pdf"}'
```

### Unit Tests
```bash
# Run tests
make test

# Run with coverage
make test-coverage
```

## Integration

### Step Functions Integration
The Lambda can be invoked from Step Functions:

```json
{
  "Type": "Task",
  "Resource": "arn:aws:lambda:region:account:function:request-ocr-function",
  "Parameters": {
    "bucket.$": "$.bucket",
    "key.$": "$.key"
  },
  "Next": "NextState"
}
```

### Direct API Integration
The function includes an optional API Gateway endpoint:
```
POST https://{api-id}.execute-api.{region}.amazonaws.com/prod/ocr
```

## Monitoring

### CloudWatch Logs
Logs are available in CloudWatch:
```
/aws/lambda/request-ocr-function
```

### Dead Letter Queue
Failed invocations are sent to the DLQ:
```
request-ocr-dlq
```

### CloudWatch Alarms
An alarm monitors DLQ messages and alerts when failures occur.

## Development

### Code Formatting
```bash
make fmt
```

### Linting (requires golangci-lint)
```bash
make lint
```

### Module Management
```bash
# Download dependencies
make mod-download

# Clean up modules
make mod-tidy
```

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Ensure Go 1.21+ is installed
   - Check GOOS=linux GOARCH=amd64 for Lambda compatibility

2. **Deployment Failures**
   - Verify AWS credentials are configured
   - Check IAM permissions for CloudFormation

3. **Runtime Errors**
   - Check CloudWatch logs for detailed error messages
   - Verify Mistral API key is correctly stored in Secrets Manager

### Useful Commands
```bash
# Check logs
sam logs -n request-ocr-function --tail

# Validate template
make validate

# Clean and rebuild
make clean && make build
```

## Cost Optimization

- Adjust memory allocation based on actual usage
- Monitor execution duration and optimize timeout
- Consider provisioned concurrency for consistent performance

## Security

- Mistral API key stored securely in AWS Secrets Manager
- IAM roles follow least privilege principle
- All communications use HTTPS/TLS encryption

## Next Steps

1. Implement your Mistral OCR logic in `main.go`
2. Add comprehensive error handling
3. Implement retry logic for API calls
4. Add monitoring and alerting
5. Optimize performance based on usage patterns
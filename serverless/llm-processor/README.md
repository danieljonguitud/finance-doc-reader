# LLM Processor Service

A Step Functions workflow that processes markdown documents using Amazon Bedrock LLM integration.

## Architecture

This service uses AWS Step Functions with direct Amazon Bedrock integration to:
1. Read markdown content from S3
2. Process it with an LLM using custom instructions
3. Save the structured response back to S3

## Deployment

Deploy the service using SAM:

```bash
cd serverless/llm-processor
sam deploy --guided  # First time
sam deploy            # Subsequent deployments
```

## Usage

### Input Format

The Step Function expects the following input:

```json
{
  "input_bucket": "your-input-bucket-name",
  "input_key": "path/to/document.md",
  "instructions": "Your processing instructions for the LLM",
  "output_bucket": "your-output-bucket-name",
  "output_key": "path/to/output.json"
}
```

### Output Format

The service outputs a JSON file containing:

```json
{
  "processed_content": "LLM response content",
  "input_metadata": {
    "input_bucket": "source-bucket",
    "input_key": "source-key",
    "instructions": "processing instructions",
    "model_id": "anthropic.claude-3-sonnet-20240229-v1:0",
    "timestamp": "2024-01-01T00:00:00.000Z"
  },
  "output_bucket": "output-bucket",
  "output_key": "output-key"
}
```

## Configuration

- **Model**: Default uses Claude 3 Sonnet via Bedrock
- **Max Tokens**: 4000 tokens per request
- **Logging**: Full execution logging to CloudWatch

## Testing

Use the AWS Step Functions console to test with the sample input file:
`sample-inputs/sample-input.json`

Make sure to:
1. Upload `sample-inputs/sample-document.md` to your input S3 bucket
2. Update bucket names in the sample input JSON
3. Execute the Step Function with the sample input
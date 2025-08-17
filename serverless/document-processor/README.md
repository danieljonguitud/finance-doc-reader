# Document Processor Service

This service provides unified document processing using AWS Textract for PDF text extraction and Amazon Bedrock for LLM processing. It replaces the previous containerized doc-reader and separate llm-processor services.

## Architecture

The service uses a Step Functions workflow that:
1. **Textract Document Analysis**: Extracts text from PDF documents using AWS Textract
2. **LLM Processing**: Processes extracted text with Amazon Bedrock (Claude 3.5 Haiku)
3. **Result Storage**: Saves structured JSON results to S3

## Deployment

```bash
cd serverless/document-processor
sam deploy --guided  # First time
sam deploy            # Subsequent deployments
```

## Testing

Test the Step Functions workflow:

```bash
# Execute with sample input
aws stepfunctions start-execution \
  --state-machine-arn <state-machine-arn> \
  --input file://sample-inputs/sample-input.json
```

## Input Format

The Step Functions expects this input format:

```json
{
  "inputBucket": "your-input-bucket",
  "inputKey": "path/to/document.pdf",
  "outputBucket": "your-output-bucket", 
  "outputKey": "processed/document.pdf-processed.json"
}
```

## Event Trigger

The service automatically triggers when PDF files are uploaded to the input S3 bucket with the pattern:
- Path: `userId/documents/*.pdf`
- Event: S3 Object Created

## Output Format

The processed results are saved to S3 in JSON format containing:
- **processingResults**: Structured financial data extracted by the LLM
- **metadata**: Processing metadata including timestamps and model info
- **textractExtraction**: Raw text extraction and document metadata from Textract

## Monitoring

- **CloudWatch Logs**: `/aws/stepfunctions/document-processor`
- **Dead Letter Queue**: Failed processing events are sent to the DLQ for investigation
- **Step Functions Console**: Monitor execution history and debug failures
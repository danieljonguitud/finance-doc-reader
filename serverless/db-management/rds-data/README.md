# RDS Proxy Lambda Function

A simple Go Lambda function that acts as a passthrough between API Gateway VTL templates and Aurora RDS Data API.

## Overview

This Lambda function enables API Gateway direct integration with Aurora PostgreSQL by:
- Accepting RDS Data API requests from API Gateway VTL templates
- Executing SQL queries using the AWS RDS Data API
- Returning raw results back to API Gateway for VTL response processing

## Architecture

```
API Gateway → VTL Request Template → Lambda (Go) → RDS Data API → Aurora
                                                     ↓
API Gateway ← VTL Response Template ← Lambda Response ← Query Results
```

## Request Format

The Lambda expects requests from API Gateway VTL in this format:

```json
{
  "resourceArn": "arn:aws:rds:region:account:cluster:cluster-name",
  "secretArn": "arn:aws:secretsmanager:region:account:secret:secret-name",
  "database": "finance_docs",
  "sql": "SELECT id, transaction_date FROM transactions WHERE user_id = :user_id LIMIT :limit",
  "parameters": [
    {"name": "user_id", "value": {"longValue": 123}},
    {"name": "limit", "value": {"longValue": 20}}
  ]
}
```

## Response Format

Returns RDS Data API response format:

```json
{
  "records": [
    [
      {"longValue": 1},
      {"stringValue": "2024-01-15"}
    ]
  ],
  "numberOfRecordsUpdated": 0,
  "generatedFields": []
}
```

## Deployment

### Build and Deploy

```bash
cd serverless/db-management/rds-data

# Build the Go binary
GOOS=linux GOARCH=amd64 go build -o main main.go

# Deploy with SAM
sam build
sam deploy --guided  # First time
sam deploy            # Subsequent deployments
```

### Dependencies

The Lambda requires:
- RDS Data API permissions for the Aurora cluster
- Secrets Manager permissions for the database secret
- API Gateway invoke permissions

## Integration

This Lambda is designed to be invoked from API Gateway methods configured in the `web-api` service. The web-api template should:

1. Change integration type from AWS (RDS) to AWS_PROXY (Lambda)
2. Update the integration URI to point to this Lambda function
3. Keep existing VTL request/response templates

## Error Handling

The Lambda handles common errors:
- **BadRequest**: Missing required parameters
- **DatabaseError**: SQL execution failures
- **InternalServerError**: AWS SDK or configuration issues

Errors are returned in API Gateway compatible format for VTL error response processing.

## Performance

- **Runtime**: Go with `provided.al2023` runtime for optimal performance
- **Memory**: 256MB (sufficient for database proxy operations)
- **Timeout**: 30 seconds (generous for most database queries)
- **Cold Start**: ~100ms typical Go Lambda cold start time

## Logging

CloudWatch logs include:
- Incoming request details
- SQL statement being executed
- Execution results and timing
- Error details for debugging

Log retention: 14 days to balance debugging needs with costs.

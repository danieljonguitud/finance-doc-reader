# Web API Service

A versioned REST API Gateway built on AWS serverless architecture with direct service integrations and VTL request/response templates.

## Architecture Philosophy

This web API follows a **serverless-first, direct integration** approach that emphasizes:

- **Direct AWS Service Integration**: Always prefer direct integrations with AWS services (S3, RDS, DynamoDB, etc.) over custom Lambda functions
- **VTL Request/Response Templates**: Heavy reliance on Velocity Template Language for request transformation and response mapping
- **Generic Lambda Adapters**: When Lambda is required, use reusable, generic functions shared across services (e.g., RDS data access function)
- **Express Step Functions**: For complex custom business logic that cannot be handled through direct integrations
- **Folder Structure Drives API**: Directory layout directly maps to API endpoint structure

## Integration Patterns

### Primary Pattern: Direct AWS Service Integration
The preferred approach for all endpoints. Use API Gateway's native integration capabilities with AWS services, leveraging VTL templates for data transformation.

### Secondary Pattern: Generic Lambda Adapters  
When direct integration isn't sufficient, use existing generic Lambda functions that provide reusable functionality (like the shared RDS data access function).

### Custom Logic Pattern: Express Step Functions
For endpoint-specific business logic that cannot be handled by direct integrations or generic adapters, implement Express Step Functions workflows.

**Important**: Avoid creating custom Lambda functions per endpoint. This maintains consistency, reduces maintenance overhead, and follows serverless best practices.

## Folder Structure & Organization

The API structure is driven by the folder organization:

```
serverless/web-api/
├── template.yaml                 # Root API Gateway, shared resources
├── v1/                          # API version namespace
│   ├── documents/               # /v1/documents endpoint
│   │   └── template.yaml        # Documents SAM application
│   ├── transactions/            # /v1/transactions endpoint  
│   │   └── template.yaml        # Transactions SAM application
│   └── [new-endpoint]/          # /v1/[new-endpoint] endpoint
│       └── template.yaml        # New endpoint SAM application
```

**Folder → Endpoint Mapping:**
- `/v1/documents/` → `POST /v1/documents`
- `/v1/transactions/` → `GET /v1/transactions`
- `/v1/[new-endpoint]/` → `HTTP_METHOD /v1/[new-endpoint]`

## SAM Nested Applications Architecture

Each endpoint is implemented as a modular SAM nested application:

### Root Template (`template.yaml`)
- API Gateway REST API definition
- Shared IAM roles and policies
- Cognito User Pool authorizer
- API deployment and staging
- Usage plans and API keys

### Endpoint Templates (`v1/[endpoint]/template.yaml`)
- API Gateway resources and methods
- Integration configurations (S3, Lambda, Step Functions)
- VTL request/response templates
- CORS handling
- Error response mapping

This modular approach enables:
- Independent development and testing of endpoints
- Consistent authentication and authorization patterns
- Shared infrastructure management
- Easy addition of new API versions or endpoints

## Core Technologies

- **API Gateway**: REST API with direct AWS service integrations
- **Velocity Template Language (VTL)**: Request/response transformation
- **Cognito User Pools**: Authentication and authorization
- **AWS IAM**: Fine-grained access control
- **CloudWatch**: Logging and monitoring
- **AWS Services**: Direct integrations (S3, RDS, Step Functions, etc.)

## Development Guidelines

### Adding a New Endpoint

1. **Create Endpoint Directory**: `mkdir v1/[new-endpoint]`

2. **Create SAM Template**: `v1/[new-endpoint]/template.yaml` with:
   - API Gateway resource and methods
   - Appropriate AWS service integration
   - VTL request/response templates
   - CORS OPTIONS method
   - Error handling patterns

3. **Update Root Template**: Add the new SAM application to `template.yaml`:
   ```yaml
   NewEndpoint:
     Type: AWS::Serverless::Application
     Properties:
       Parameters:
         ProjectName: !Ref ProjectName
         ApiGatewayExecutionRoleArn: !GetAtt ApiGatewayExecutionRole.Arn
         WebApi: !Ref WebApi
         V1Resource: !Ref V1Resource
         CognitoAuthorizerId: !Ref CognitoAuthorizer
       Location: ./v1/[new-endpoint]/template.yaml
   ```

### VTL Template Best Practices

- Use request templates to transform client requests into AWS service formats
- Use response templates to standardize API responses
- Handle authentication context extraction (`$context.authorizer.claims.sub`)
- Implement proper error handling with appropriate HTTP status codes
- Include CORS headers in all responses

### Authentication Patterns

All endpoints use consistent Cognito User Pool authentication:
- `AuthorizationType: COGNITO_USER_POOLS`
- `AuthorizerId: !Ref CognitoAuthorizer`
- Extract user ID: `$context.authorizer.claims.sub`
- OPTIONS methods: `AuthorizationType: NONE` (for CORS)

## Deployment

### Prerequisites
1. Deploy the `core-infra` stack (provides shared resources)
2. Deploy the `db-management` stack (provides RDS data function)
3. Deploy the `auth-services` stack (provides Cognito User Pool)

### Deploy the Web API
```bash
cd serverless/web-api
sam deploy --guided  # First time
sam deploy            # Subsequent deployments
```

## API Usage

### Base URL
```
https://{api-id}.execute-api.{region}.amazonaws.com/dev/v1/
```

### Authentication
All endpoints require Cognito User Pool authentication with JWT tokens in the Authorization header.

### Available Endpoints

- `POST /v1/documents` - Upload documents directly to S3
- `GET /v1/transactions` - Query financial transactions with filtering

## Monitoring

- **CloudWatch Logs**: `/aws/apigateway/web-api`
- **API Gateway Metrics**: Available in CloudWatch console
- **Usage Plans**: Rate limiting and throttling enabled
- **Error Tracking**: Structured error responses with appropriate HTTP status codes

## Integration Examples

### Direct S3 Integration (Documents)
- Request template transforms client data for S3 PUT operation
- Direct integration with S3 service
- Response template formats upload confirmation
- No Lambda function required

### Generic Lambda Integration (Transactions)  
- Request template builds SQL query from parameters
- Integration with shared RDS data access function
- Response template formats database results
- Reuses existing generic Lambda adapter

## Security

- **Cognito Authentication**: Required for all data endpoints
- **IAM Role-Based Access**: Fine-grained service permissions
- **CORS Configuration**: Cross-origin requests enabled
- **API Rate Limiting**: Usage plans and throttling
- **CloudWatch Audit Trail**: Complete request/response logging
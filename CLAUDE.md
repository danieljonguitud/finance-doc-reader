# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a finance document reader system that processes PDF documents for financial data analysis. The system uses a modular serverless architecture with multiple independent services that work together to provide a complete document processing and API solution.

The system is designed as serverless AWS infrastructure using CloudFormation/SAM templates with Step Functions workflows and managed AWS services.

## Architecture

### Core Services

1. **Core Infrastructure** (`core-infra/`): Shared AWS resources including S3 buckets for input and Aurora PostgreSQL database
2. **Authentication Services** (`auth-services/`): Cognito User Pools for user authentication and JWT token management
3. **Database Management** (`serverless/db-management/`): Generic RDS data access functions, database migrations, and schema management
4. **Web API** (`serverless/web-api/`): REST API Gateway with direct AWS service integrations and VTL templates
5. **Document Processor** (`serverless/document-processor/`): Unified Step Functions workflow using AWS Textract and Amazon Bedrock

### Service Architecture Philosophy

- **Modular Design**: Each service can be deployed independently after dependencies
- **Direct AWS Integrations**: Prefer direct AWS service integrations over custom Lambda functions
- **Generic Adapters**: When Lambda is needed, use reusable functions shared across services
- **Step Functions for Complex Logic**: Use Express Step Functions for custom business workflows
- **Infrastructure as Code**: All infrastructure managed through CloudFormation/SAM templates

### Key Technologies

- **Amazon Bedrock**: LLM processing for financial data extraction
- **AWS Step Functions**: Orchestration for complex workflows
- **AWS API Gateway**: REST API with direct service integrations and VTL templates
- **AWS Cognito**: User authentication and authorization
- **AWS RDS Aurora**: PostgreSQL database for structured data storage
- **AWS S3**: Input/output storage for PDF documents and processed results
- **AWS CloudFormation/SAM**: Infrastructure as code

## File Structure

```
├── core-infra/                          # Shared AWS infrastructure
│   └── template.yaml                    # S3 buckets, Aurora database, shared resources
├── auth-services/                       # Authentication and user management
│   └── template.yaml                    # Cognito User Pools, authentication flows
├── serverless/
│   ├── db-management/                   # Database operations and management
│   │   ├── template.yaml                # Generic RDS data access function
│   │   ├── rds-data/                    # Lambda function for database operations
│   │   ├── migrations/                  # Database migration scripts
│   │   └── schema/                      # Database schema definitions
│   ├── web-api/                         # REST API Gateway service
│   │   ├── template.yaml                # API Gateway, shared resources
│   │   ├── CLAUDE.md                    # Web API architecture documentation
│   │   └── v1/                          # API version 1
│   │       ├── documents/               # Document upload endpoints
│   │       └── transactions/            # Transaction query endpoints
│   └── document-processor/              # Document processing pipeline
│       ├── template.yaml                # Step Functions, processing workflow
│       ├── document-processor-state-machine.yaml # Step Functions definition
│       ├── request-ocr/                 # OCR processing functions
│       └── sample-inputs/               # Test inputs for Step Functions
```

## Service Dependencies

**Deployment Order**:
1. `core-infra` - Provides shared resources (S3, RDS, VPC)
2. `auth-services` - Provides Cognito User Pools for authentication
3. `db-management` - Provides generic database access functions
4. `web-api` - Provides REST API endpoints (depends on all above)
5. `document-processor` - Provides document processing pipeline (depends on core-infra)

**Service Interactions**:
- **Web API** → **Database Management**: Uses generic RDS function for data operations
- **Web API** → **Authentication Services**: Uses Cognito for user authentication
- **Web API** → **Core Infrastructure**: Uploads files to S3, triggers document processing
- **Document Processor** → **Core Infrastructure**: Reads from input S3, writes to output S3

## Development Commands

### Infrastructure Deployment

Deploy in dependency order:

```bash
# Any root template
cd core-infra
sam deploy --guided  # First time
sam deploy            # Subsequent deployments
```

### Testing Services

Pending

## Service Configuration

### Web API Service
- **Architecture**: Direct AWS service integrations with VTL request/response templates
- **Authentication**: Cognito User Pools with JWT tokens
- **Documentation**: See `serverless/web-api/CLAUDE.md` for detailed API architecture

### Document Processing Pipeline
- **Input**: PDF files uploaded to S3 bucket with path `userId/documents/*.pdf`
- **Processing**: AWS Textract → Amazon Bedrock (Claude 3.5 Haiku) → Structured output
- **Output**: JSON results stored in output S3 bucket

### Database Management
- **Generic Function**: Reusable RDS data access Lambda function
- **Usage**: Shared across services for database operations
- **Schema**: PostgreSQL with user-based data isolation

## Reminders 
- All our step functions should be in yaml, use the AWS::Serverless::StateMachine and DefinitionUri to refer to a file

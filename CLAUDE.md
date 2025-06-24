# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a finance document reader that uses the marker-pdf library to convert PDF documents to markdown format. The system is designed to run as a containerized Fargate task on AWS ECS, orchestrated by CloudFormation/SAM templates.

## Architecture

### Core Components

1. **Core Infrastructure** (`core-infra/`): Defines shared AWS resources including S3 buckets for input/output and ECS cluster
2. **Document Reader Service** (`serverless/doc-reader/`): Containerized application that processes PDFs using marker-pdf library
3. **Docker Container**: Python-based container with marker-pdf, torch, and AWS CLI for PDF processing

### Key Technologies

- **marker-pdf**: Primary PDF to markdown conversion library
- **Docker**: Containerization with ARM64 architecture support
- **AWS Fargate**: Serverless container orchestration
- **AWS S3**: Input/output storage
- **AWS CloudFormation/SAM**: Infrastructure as code

## Development Commands

### Infrastructure Deployment

Deploy core infrastructure:
```bash
cd core-infra
sam deploy --guided  # First time
sam deploy            # Subsequent deployments
```

Deploy document reader service:
```bash
cd serverless/doc-reader
sam deploy --guided  # First time
sam deploy            # Subsequent deployments
```

### Container Operations

Build and deploy container image:
```bash
cd serverless/doc-reader
./deploy-container.sh <stack-name> <aws-region>
# Example: ./deploy-container.sh doc-reader us-east-1
```

Test container locally with Docker Compose:
```bash
cd serverless/doc-reader/src
docker-compose up --build
```

Test Fargate task execution:
```bash
cd serverless/doc-reader
./test-fargate-task.sh <stack-name> <aws-region>
# Example: ./test-fargate-task.sh doc-reader us-east-1
```

## Container Configuration

### Environment Variables

The container expects these environment variables:
- `INPUT_S3_BUCKET`: S3 bucket containing PDF files to process
- `OUTPUT_S3_URI_PREFIX`: S3 URI prefix for output markdown files

### Resource Requirements

- **CPU**: 4 vCPU (4096 CPU units)
- **Memory**: 16 GB (16384 MB)
- **Platform**: ARM64 architecture

### Model Caching

The container pre-downloads marker-pdf models during build to `/opt/marker_cache` to improve runtime performance.

## File Structure

```
├── core-infra/           # Shared AWS infrastructure
│   └── template.yaml     # S3 buckets, ECS cluster
├── serverless/
│   └── doc-reader/       # Document processing service
│       ├── src/
│       │   ├── Dockerfile        # Container definition
│       │   ├── entrypoint.sh     # Container entry script
│       │   ├── compose.yaml      # Local development
│       │   ├── inputs/           # Local test inputs
│       │   └── outputs/          # Local test outputs
│       ├── template.yaml         # ECS task definition, IAM roles
│       ├── deploy-container.sh   # Container deployment script
│       └── test-fargate-task.sh  # Task testing script
```

## Deployment Workflow

1. Deploy core infrastructure stack first
2. Deploy document reader service stack
3. Build and push container image using `deploy-container.sh`
4. Test with sample PDFs using `test-fargate-task.sh`

## Monitoring

Container logs are available in CloudWatch:
- Log Group: `/ecs/doc-reader`
- Retention: 30 days
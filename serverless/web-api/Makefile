# Web API Service Makefile
# Handles SAM build, deploy, and API deployment

.PHONY: help build deploy deploy-api clean logs all

# Default target
help:
	@echo "Available targets:"
	@echo "  build       - Build the SAM application"
	@echo "  deploy      - Deploy the application using SAM"
	@echo "  deploy-api  - Deploy API Gateway stage using AWS CLI"
	@echo "  clean       - Clean build artifacts"
	@echo "  logs        - Tail CloudWatch logs for the API"
	@echo "  all         - Build, deploy SAM, and deploy API"

# Build the SAM application
build:
	@echo "Building SAM application..."
	sam build

# Deploy the application
deploy:
	@echo "Deploying SAM application..."
	sam deploy

# Deploy API Gateway stage using AWS CLI
deploy-api:
	@echo "Getting API Gateway ID from CloudFormation stack..."
	$(eval API_ID := $(shell aws cloudformation describe-stacks --stack-name web-api-local --query 'Stacks[0].Outputs[?OutputKey==`ApiId`].OutputValue' --output text))
	@echo "API Gateway ID: $(API_ID)"
	@echo "Creating deployment..."
	$(eval DEPLOYMENT_ID := $(shell aws apigateway create-deployment --rest-api-id $(API_ID) --stage-name dev --description "Makefile deployment" --query 'id' --output text))
	@echo "Deployment ID: $(DEPLOYMENT_ID)"
	@echo "API Gateway deployed successfully!"
	@echo "API URL: https://$(API_ID).execute-api.$(shell aws configure get region).amazonaws.com/dev"

# Build, deploy SAM, and deploy API in sequence
all: build deploy deploy-api

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf .aws-sam/

# Tail API Gateway logs
logs:
	@echo "Tailing API Gateway logs..."
	aws logs tail /aws/apigateway/web-api --follow

# Deploy with guided setup (first time)
deploy-guided:
	@echo "Running guided deployment..."
	sam deploy --guided

# Atlas Database Management for Finance Doc Reader
# Uses AWS CLI to dynamically retrieve database connection parameters

# Variables
PROJECT_NAME = finance-doc-core-infra
STACK_NAME = $(PROJECT_NAME)
REGION = $(shell aws configure get region || echo "us-west-2")

# Database connection parameters from CloudFormation exports
DB_ENDPOINT = $(shell aws cloudformation list-exports --query "Exports[?Name=='$(STACK_NAME)-aurora-cluster-endpoint'].Value" --output text --region $(REGION))
DB_NAME = $(shell aws cloudformation list-exports --query "Exports[?Name=='$(STACK_NAME)-database-name'].Value" --output text --region $(REGION))
SECRET_ARN = $(shell aws cloudformation list-exports --query "Exports[?Name=='$(STACK_NAME)-database-secret-arn'].Value" --output text --region $(REGION))
BASTION_INSTANCE_ID = $(shell aws cloudformation list-exports --query "Exports[?Name=='$(STACK_NAME)-bastion-instance-id'].Value" --output text --region $(REGION))

# Extract credentials from AWS Secrets Manager
DB_CREDENTIALS = $(shell aws secretsmanager get-secret-value --secret-id $(SECRET_ARN) --query SecretString --output text --region $(REGION))
DB_USERNAME = $(shell echo '$(DB_CREDENTIALS)' | jq -r .username)
DB_PASSWORD = $(shell echo '$(DB_CREDENTIALS)' | jq -r .password)
DB_PASSWORD_ENCODED = $(shell echo '$(DB_PASSWORD)' | jq -rR '@uri')

# Build PostgreSQL connection string (via Session Manager tunnel)
DATABASE_URL = postgres://$(DB_USERNAME):$(DB_PASSWORD_ENCODED)@localhost:3306/$(DB_NAME)?sslmode=require

# Session Manager tunnel process file
TUNNEL_PID_FILE = /tmp/ssm-tunnel-$(STACK_NAME).pid

.PHONY: help setup status diff migrate-new migrate-apply migrate-status migrate-init plan apply validate inspect clean tunnel-start tunnel-stop tunnel-status

help: ## Show this help message
	@echo "Atlas Database Management Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

check-deps: ## Check if required tools are installed
	@echo "Checking dependencies..."
	@command -v atlas >/dev/null 2>&1 || { echo "Atlas CLI not found. Install from https://atlasgo.io/getting-started"; exit 1; }
	@command -v aws >/dev/null 2>&1 || { echo "AWS CLI not found. Please install AWS CLI"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "jq not found. Please install jq"; exit 1; }
	@echo "All dependencies found!"

tunnel-start: check-deps ## Start Session Manager tunnel to Aurora (required before other commands)
	@echo "Starting Session Manager tunnel to Aurora..."
	@echo "Bastion Instance: $(BASTION_INSTANCE_ID)"
	@echo "Database Endpoint: $(DB_ENDPOINT)"
	@if [ -f "$(TUNNEL_PID_FILE)" ] && kill -0 $$(cat $(TUNNEL_PID_FILE)) 2>/dev/null; then \
		echo "⚠️  Tunnel already running (PID: $$(cat $(TUNNEL_PID_FILE)))"; \
	else \
		echo "🚀 Creating tunnel via Session Manager..."; \
		aws ssm start-session \
			--target $(BASTION_INSTANCE_ID) \
			--document-name AWS-StartPortForwardingSessionToRemoteHost \
			--parameters '{"host":["$(DB_ENDPOINT)"],"portNumber":["3306"],"localPortNumber":["3306"]}' \
			--region $(REGION) & \
		echo $$! > $(TUNNEL_PID_FILE); \
		echo "✅ Tunnel started! PID: $$(cat $(TUNNEL_PID_FILE))"; \
		echo "📋 Use 'make tunnel-stop' to close the tunnel"; \
		echo "⏳ Waiting 3 seconds for tunnel to establish..."; \
		sleep 3; \
	fi

tunnel-stop: ## Stop Session Manager tunnel
	@if [ -f "$(TUNNEL_PID_FILE)" ]; then \
		echo "🛑 Stopping Session Manager tunnel..."; \
		if kill -0 $$(cat $(TUNNEL_PID_FILE)) 2>/dev/null; then \
			kill $$(cat $(TUNNEL_PID_FILE)); \
			echo "✅ Tunnel stopped"; \
		else \
			echo "⚠️  Tunnel process not found"; \
		fi; \
		rm -f $(TUNNEL_PID_FILE); \
	else \
		echo "❌ No tunnel PID file found"; \
	fi

tunnel-status: ## Check Session Manager tunnel status
	@if [ -f "$(TUNNEL_PID_FILE)" ] && kill -0 $$(cat $(TUNNEL_PID_FILE)) 2>/dev/null; then \
		echo "✅ Tunnel is running (PID: $$(cat $(TUNNEL_PID_FILE)))"; \
		echo "🔗 Database accessible at localhost:3306"; \
	else \
		echo "❌ Tunnel is not running"; \
		echo "💡 Run 'make tunnel-start' to create tunnel"; \
	fi

setup: tunnel-status check-deps ## Setup Atlas configuration and validate connection
	@echo "Setting up Atlas for Aurora PostgreSQL..."
	@echo "Database endpoint: $(DB_ENDPOINT) (via tunnel)"
	@echo "Database name: $(DB_NAME)"
	@if [ -f "$(TUNNEL_PID_FILE)" ] && kill -0 $$(cat $(TUNNEL_PID_FILE)) 2>/dev/null; then \
		echo "Testing connection through tunnel..."; \
		atlas schema inspect --url "$(DATABASE_URL)" > /dev/null && echo "✅ Connection successful!" || { echo "❌ Connection failed!"; exit 1; }; \
	else \
		echo "❌ No tunnel found. Run 'make tunnel-start' first"; \
		exit 1; \
	fi

status: ## Show current database schema status
	@echo "Database Schema Status:"
	@atlas schema inspect --url "$(DATABASE_URL)"

diff: ## Show differences between current schema and desired schema
	@echo "Schema differences:"
	@atlas schema diff --from "$(DATABASE_URL)" --to "file://schema" --dev-url "docker://postgres/17/dev"

migrate-new:
	@echo "Creating new migration..."
	@read -p "Enter migration name: " name; \
	atlas migrate diff "$$name" --dir "file://migrations" --to "file://schema" --dev-url "docker://postgres/17/dev"

migrate-apply: ## Apply pending migrations
	@echo "Applying pending migrations..."
	@atlas migrate apply --url "$(DATABASE_URL)" --dir "file://migrations"

migrate-status: ## Show migration status
	@echo "Migration status:"
	@atlas migrate status --url "$(DATABASE_URL)" --dir "file://migrations"

debug-connection: ## Debug database connection parameters
	@echo "Connection Debug Info:"
	@echo "Region: $(REGION)"
	@echo "Stack Name: $(STACK_NAME)"
	@echo "DB Endpoint: $(DB_ENDPOINT)"
	@echo "DB Name: $(DB_NAME)"
	@echo "Secret ARN: $(SECRET_ARN)"
	@echo "DB Username: $(DB_USERNAME)"
	@echo "Bastion Instance: $(BASTION_INSTANCE_ID)"
	@echo "Database URL (via tunnel): postgres://$(DB_USERNAME):****@localhost:5432/$(DB_NAME)?sslmode=require"
	@echo ""
	@echo "Session Manager Connection Workflow:"
	@echo "1. make tunnel-start  # Start Session Manager tunnel"
	@echo "2. make setup         # Test Atlas connection"
	@echo "3. make apply         # Apply schema changes"
	@echo "4. make tunnel-stop   # Stop tunnel when done"

# Environment-specific targets
dev-status: ## Show status for development environment
	$(MAKE) status STACK_NAME=finance-doc-core-infra-dev

staging-status: ## Show status for staging environment
	$(MAKE) status STACK_NAME=finance-doc-core-infra-staging

prod-status: ## Show status for production environment
	$(MAKE) status STACK_NAME=finance-doc-core-infra-prod

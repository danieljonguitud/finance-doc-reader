# Makefile for building the Go Lambda function

# Build the Go executable for Linux (required for Lambda)
# GOOS=linux: Target operating system is Linux
# GOARCH=arm64: Target architecture is ARM64 (matches the function's Architecture in template.yaml)
# CGO_ENABLED=0: Disable CGO for static compilation
# -o bootstrap: Output file name is 'bootstrap'
# main.go: The main Go source file
build-getItemsFunction:
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -tags lambda.norpc -o bootstrap main.go
	cp bootstrap $(ARTIFACTS_DIR)

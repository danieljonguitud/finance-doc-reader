package main

import (
	"context"
	"fmt"
	"log"

	"request-ocr/mistral-request"
	"request-ocr/s3-helper"

	"github.com/aws/aws-lambda-go/lambda"
)

type RequestOCRInput struct {
	Bucket string `json:"bucket"`
	Key    string `json:"key"`
}

type RequestOCROutput struct {
	ExtractedText string `json:"extractedText"`
}

func handler(ctx context.Context, event RequestOCRInput) (RequestOCROutput, error) {
	log.Printf("Processing OCR request for s3://%s/%s", event.Bucket, event.Key)

	if event.Bucket == "" {
		return RequestOCROutput{}, fmt.Errorf("bucket is required")
	}
	if event.Key == "" {
		return RequestOCROutput{}, fmt.Errorf("key is required")
	}

	pdfBase64Str, err := s3helper.RetrieveFile(ctx, event.Bucket, event.Key)
	if err != nil {
		return RequestOCROutput{}, fmt.Errorf("failed to retrieve PDF from S3: %w", err)
	}

	extractedText, err := mistralrequest.RequestPDFToMD(ctx, pdfBase64Str)
	if err != nil {
		return RequestOCROutput{}, fmt.Errorf("failed to extract text from PDF: %w", err)
	}

	log.Printf("Successfully extracted %d characters of text", len(extractedText))
	return RequestOCROutput{
		ExtractedText: extractedText,
	}, nil
}

func main() {
	lambda.Start(handler)
}

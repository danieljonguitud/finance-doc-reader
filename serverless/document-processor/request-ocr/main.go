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
	log.Printf("Event %s", event)
	pdfBase64Str, err := s3Helper.RetrieveFile(ctx, event.Bucket, event.Key)
	if err != nil {
		panic(fmt.Sprintf("failed getting pdf from s3: %v", err))
	}

	extractedText, err := mistralRequest.RequestPDFtoMD(pdfBase64Str)
	if err != nil {
		panic(fmt.Sprintf("failed getting pdf from s3: %v", err))
	}

	return RequestOCROutput{
		ExtractedText: extractedText,
	}, nil
}

func main() {
	lambda.Start(handler)
}

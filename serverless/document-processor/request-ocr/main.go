package main

import (
	"context"
	"log"

	"github.com/aws/aws-lambda-go/lambda"
)

type RequestOCRInput struct {
	Bucket string `json:"bucket"`
	Key    string `json:"key"`
}

func handler(ctx context.Context, event RequestOCRInput) {
	log.Printf("Event %s", event)
}

func main() {
	lambda.Start(handler)
}

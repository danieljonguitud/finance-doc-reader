package main

import (
	"context"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
)

type RequestOCRInput struct {
	Bucket string `json:"bucket"`
	Key    string `json:"key"`
}

var (
	mistralApiEndpoint string
	mistralApiSecret   string
)

func init() {
	mistralApiEndpoint = os.Getenv("MISTRAL_API_ENDPOINT")
	mistralApiSecret = os.Getenv("MISTRAL_API_SECRET")
}

func handler(ctx context.Context, event RequestOCRInput) {
	log.Printf("Event %s", event)
}

func main() {
	lambda.Start(handler)
}

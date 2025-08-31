package main

import (
	"context"
	"log"
	"os"

	"rds-data/internal/errors"
	"rds-data/internal/operations"
	"rds-data/types"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/rdsdata"
)

var (
	dbConn types.DBConn
)

func init() {
	dbConn.ResourceArn = os.Getenv("AURORA_CLUSTER_ARN")
	dbConn.SecretArn = os.Getenv("DATABASE_SECRET_ARN")
	dbConn.DatabaseName = os.Getenv("DATABASE_NAME")

	if dbConn.ResourceArn == "" {
		log.Panicf("AURORA_CLUSTER_ARN environment variable not set")
	}

	if dbConn.SecretArn == "" {
		log.Panicf("DATABASE_SECRET_ARN environment variable not set")
	}

	if dbConn.DatabaseName == "" {
		log.Panicf("DATABASE_NAME environment variable not set")
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Panicf("Failed to load AWS config: %v", err)
	}

	dbConn.RdsClient = rdsdata.NewFromConfig(cfg)
}

func main() {
	lambda.Start(handler)
}

func handler(ctx context.Context, request types.DataRequest) (*types.DataResponse, error) {
	log.Printf("Received request: %s", request)
	var result *types.DataResponse
	var err *errors.LambdaError

	if request.Operation == "" {
		return nil, &errors.LambdaError{
			ErrorMessage: "400: Operation is required",
		}
	}

	switch request.Operation {
	case "query":
		result, err = operations.Query(ctx, &request, &dbConn)
	default:
		return nil, &errors.LambdaError{
			ErrorMessage: "400: Unsupported operation",
		}
	}

	if err != nil {
		return nil, &errors.LambdaError{
			ErrorMessage: err.ErrorMessage,
		}
	}

	return result, nil
}

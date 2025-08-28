package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/rdsdata"
	"github.com/aws/aws-sdk-go-v2/service/rdsdata/types"
)

type RDSDataRequest struct {
	SQL           string          `json:"sql"`
	ParametersRaw json.RawMessage `json:"parameters"`
}

type ParameterJSON struct {
	Name        string   `json:"name"`
	StringValue *string  `json:"stringValue,omitempty"`
	LongValue   *int64   `json:"longValue,omitempty"`
	DoubleValue *float64 `json:"doubleValue,omitempty"`
	BoolValue   *bool    `json:"boolValue,omitempty"`
	IsNull      *bool    `json:"isNull,omitempty"`
}

type LambdaError struct {
	ErrorMessage string `json:"errorMessage"`
}

func (e *LambdaError) Error() string {
	return e.ErrorMessage
}

var (
	resourceArn  string
	secretArn    string
	databaseName string
	rdsClient    *rdsdata.Client
)

func init() {
	resourceArn = os.Getenv("AURORA_CLUSTER_ARN")
	secretArn = os.Getenv("DATABASE_SECRET_ARN")
	databaseName = os.Getenv("DATABASE_NAME")

	if resourceArn == "" {
		log.Panicf("AURORA_CLUSTER_ARN environment variable not set")
	}

	if secretArn == "" {
		log.Panicf("DATABASE_SECRET_ARN environment variable not set")
	}

	if databaseName == "" {
		log.Panicf("DATABASE_NAME environment variable not set")
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Panicf("Failed to load AWS config: %v", err)
	}

	rdsClient = rdsdata.NewFromConfig(cfg)

}

func main() {
	lambda.Start(handler)
}

func parseParameters(rawParams json.RawMessage) ([]types.SqlParameter, error) {
	var paramJSONs []ParameterJSON
	if err := json.Unmarshal(rawParams, &paramJSONs); err != nil {
		return nil, fmt.Errorf("failed to unmarshal parameters: %v", err)
	}

	var sqlParams []types.SqlParameter
	for _, p := range paramJSONs {
		param := types.SqlParameter{
			Name: &p.Name,
		}

		if p.StringValue != nil {
			param.Value = &types.FieldMemberStringValue{Value: *p.StringValue}
		} else if p.LongValue != nil {
			param.Value = &types.FieldMemberLongValue{Value: *p.LongValue}
		} else if p.DoubleValue != nil {
			param.Value = &types.FieldMemberDoubleValue{Value: *p.DoubleValue}
		} else if p.BoolValue != nil {
			param.Value = &types.FieldMemberBooleanValue{Value: *p.BoolValue}
		} else if p.IsNull != nil && *p.IsNull {
			param.Value = &types.FieldMemberIsNull{Value: true}
		}

		sqlParams = append(sqlParams, param)
	}

	return sqlParams, nil
}

func handler(ctx context.Context, request RDSDataRequest) (*rdsdata.ExecuteStatementOutput, error) {
	log.Printf("Received RDS Data API request with SQL: %s", request.SQL)

	if request.SQL == "" {
		return nil, &LambdaError{
			ErrorMessage: "SQL query is required",
		}
	}

	input := &rdsdata.ExecuteStatementInput{
		ResourceArn: &resourceArn,
		SecretArn:   &secretArn,
		Database:    &databaseName,
		Sql:         &request.SQL,
	}

	if len(request.ParametersRaw) > 0 {
		sqlParams, err := parseParameters(request.ParametersRaw)
		if err != nil {
			log.Printf("Failed to parse parameters: %v", err)
			return nil, &LambdaError{
				ErrorMessage: "Failed to parse query parameters",
			}
		}
		input.Parameters = sqlParams
		log.Printf("Parsed %d parameters successfully", len(sqlParams))
	}

	log.Printf("Executing SQL: %s", *input.Sql)
	result, err := rdsClient.ExecuteStatement(ctx, input)
	if err != nil {
		log.Printf("Failed to execute statement: %v", err)

		// Check for specific AWS errors
		errorMsg := err.Error()
		if strings.Contains(errorMsg, "DatabaseResumingException") {
			return nil, &LambdaError{
				ErrorMessage: "Database is resuming, please retry",
			}
		}

		// Default to internal server error
		return nil, &LambdaError{
			ErrorMessage: "Failed to execute database query",
		}
	}

	log.Printf("Successfully executed statement, returned %d records", len(result.Records))

	return result, nil
}

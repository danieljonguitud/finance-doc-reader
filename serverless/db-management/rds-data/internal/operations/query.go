package operations

import (
	"context"
	"encoding/json"
	"log"
	"regexp"
	"strings"

	"rds-data/internal/errors"
	"rds-data/internal/operations/utils"
	"rds-data/types"

	"github.com/aws/aws-sdk-go-v2/service/rdsdata"
)

func Query(ctx context.Context, request *types.DataRequest, dbConn *types.DBConn) (*types.DataResponse, *errors.LambdaError) {
	sql := addCountToQuery(request.SQL)

	input := &rdsdata.ExecuteStatementInput{
		ResourceArn:     &dbConn.ResourceArn,
		SecretArn:       &dbConn.SecretArn,
		Database:        &dbConn.DatabaseName,
		Sql:             &sql,
		FormatRecordsAs: "JSON",
	}

	if len(request.ParametersRaw) > 0 {
		sqlParams, err := utils.ParseParameters(request.ParametersRaw)
		if err != nil {
			log.Printf("Failed to parse parameters: %v", err)
			return nil, &errors.LambdaError{
				ErrorMessage: "400: Failed to parse query parameters",
			}
		}
		input.Parameters = sqlParams
		log.Printf("Parsed %d parameters successfully", len(sqlParams))
	}

	log.Printf("Executing SQL: %s", sql)
	result, err := dbConn.RdsClient.ExecuteStatement(ctx, input)
	if err != nil {
		log.Printf("Failed to execute statement: %v", err)

		errorMsg := err.Error()
		if strings.Contains(errorMsg, "DatabaseResumingException") {
			return nil, &errors.LambdaError{
				ErrorMessage: "503: Database is resuming, please retry",
			}
		}

		return nil, &errors.LambdaError{
			ErrorMessage: "400: Failed to execute database query",
		}
	}

	log.Printf("Successfully executed statement")

	dataResponse, err := processJSONResults(result)
	if err != nil {
		return nil, &errors.LambdaError{
			ErrorMessage: "400: Failed to process query results",
		}
	}

	return dataResponse, nil
}

func addCountToQuery(sql string) string {
	selectPattern := regexp.MustCompile(`(?i)^\s*SELECT\s+`)
	if !selectPattern.MatchString(sql) {
		return sql
	}

	if strings.Contains(strings.ToUpper(sql), "COUNT(*) OVER()") {
		return sql
	}

	fromPattern := regexp.MustCompile(`(?i)\s+FROM\s+`)
	fromMatch := fromPattern.FindStringIndex(sql)

	if fromMatch == nil {
		return sql
	}

	beforeFrom := sql[:fromMatch[0]]
	afterFrom := sql[fromMatch[0]:]

	return beforeFrom + ", COUNT(*) OVER() as total_count" + afterFrom
}

func processJSONResults(result *rdsdata.ExecuteStatementOutput) (*types.DataResponse, error) {
	response := &types.DataResponse{
		Records: make([]map[string]any, 0),
	}

	if result.FormattedRecords == nil || *result.FormattedRecords == "" {
		return response, nil
	}

	var records []map[string]any
	if err := json.Unmarshal([]byte(*result.FormattedRecords), &records); err != nil {
		return nil, err
	}

	if len(records) > 0 {
		if totalCount, ok := records[0]["total_count"]; ok {
			if totalFloat, ok := totalCount.(float64); ok {
				total := int32(totalFloat)
				response.Total = &total
			}
		}

		for _, record := range records {
			delete(record, "total_count")
			response.Records = append(response.Records, record)
		}
	}

	return response, nil
}

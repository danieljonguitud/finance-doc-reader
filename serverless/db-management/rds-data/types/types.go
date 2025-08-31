package types

import (
	"encoding/json"

	"github.com/aws/aws-sdk-go-v2/service/rdsdata"
)

type DataRequestLater struct {
	Operation string         `json:"operation"`
	Table     string         `json:"table"`
	Fields    []string       `json:"fields,omitempty"`
	Filters   map[string]any `json:"filters,omitempty"`
	OrderBy   string         `json:"orderBy,omitempty"`
	OrderDir  string         `json:"orderDir,omitempty"`
	Limit     *int           `json:"limit,omitempty"`
	Offset    *int           `json:"offset,omitempty"`
	Data      map[string]any `json:"data,omitempty"`
}

type DataRequest struct {
	Operation     string          `json:"operation"`
	SQL           string          `json:"sql"`
	ParametersRaw json.RawMessage `json:"parameters"`
}

type DBConn struct {
	ResourceArn  string
	SecretArn    string
	DatabaseName string
	RdsClient    *rdsdata.Client
}

type DataResponse struct {
	Records []map[string]any `json:"records"`
	Total   *int32           `json:"total,omitempty"`
}

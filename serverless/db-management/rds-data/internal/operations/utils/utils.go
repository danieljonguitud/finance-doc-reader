package utils

import (
	"encoding/json"
	"fmt"
	rdsTypes "github.com/aws/aws-sdk-go-v2/service/rdsdata/types"
)

type ParameterJSON struct {
	Name        string   `json:"name"`
	StringValue *string  `json:"stringValue,omitempty"`
	LongValue   *int64   `json:"longValue,omitempty"`
	DoubleValue *float64 `json:"doubleValue,omitempty"`
	BoolValue   *bool    `json:"boolValue,omitempty"`
	IsNull      *bool    `json:"isNull,omitempty"`
}

func ParseParameters(rawParams json.RawMessage) ([]rdsTypes.SqlParameter, error) {
	var paramJSONs []ParameterJSON
	if err := json.Unmarshal(rawParams, &paramJSONs); err != nil {
		return nil, fmt.Errorf("failed to unmarshal parameters: %v", err)
	}

	var sqlParams []rdsTypes.SqlParameter
	for _, p := range paramJSONs {
		param := rdsTypes.SqlParameter{
			Name: &p.Name,
		}

		if p.StringValue != nil {
			param.Value = &rdsTypes.FieldMemberStringValue{Value: *p.StringValue}
		} else if p.LongValue != nil {
			param.Value = &rdsTypes.FieldMemberLongValue{Value: *p.LongValue}
		} else if p.DoubleValue != nil {
			param.Value = &rdsTypes.FieldMemberDoubleValue{Value: *p.DoubleValue}
		} else if p.BoolValue != nil {
			param.Value = &rdsTypes.FieldMemberBooleanValue{Value: *p.BoolValue}
		} else if p.IsNull != nil && *p.IsNull {
			param.Value = &rdsTypes.FieldMemberIsNull{Value: true}
		}

		sqlParams = append(sqlParams, param)
	}

	return sqlParams, nil
}

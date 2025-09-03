import { RDSDataClient, SqlParameter } from "@aws-sdk/client-rds-data"

export interface DataRequest {
    operation: "query" | "create" | "update" | "delete"
    sql: string
    parameters: SqlParameter[]
}

export interface Parameter {
    value: any
}

export interface DataQueryResponse {
    records: Record<string, any>[]
    total?: number
}

export interface DataCreateResponse {
    record?: Record<string, any>
    recordsCreated?: number
}

export type DataConn = {
    resourceArn: string
    secretArn: string
    databaseName: string
    rdsClient: RDSDataClient
}

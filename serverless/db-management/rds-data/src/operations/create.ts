import {
    ExecuteStatementCommand,
    BatchExecuteStatementCommand,
    ExecuteStatementCommandOutput,
    BatchExecuteStatementCommandOutput,
    SqlParameter
} from "@aws-sdk/client-rds-data"
import { DataConn, DataCreateResponse, DataRequest } from "../types"
import { normalizeObj } from "./utils"

export const create = async (request: DataRequest, dataConn: DataConn): Promise<DataCreateResponse> => {
    const { sql, parameters } = request

    const isBulkInsert = Array.isArray(parameters) &&
        parameters.length > 0 &&
        Array.isArray(parameters[0])

    console.log("Create operation - Bulk insert:", isBulkInsert)
    console.log("SQL:", sql)

    if (isBulkInsert) {
        return await executeBulkInsert(sql, parameters as SqlParameter[][], dataConn)
    } else {
        return await executeSingleInsert(sql, parameters as SqlParameter[], dataConn)
    }
}

const executeSingleInsert = async (
    sql: string,
    parameters: SqlParameter[],
    dataConn: DataConn
): Promise<DataCreateResponse> => {
    const { resourceArn, secretArn, databaseName: database, rdsClient } = dataConn

    const cmd = new ExecuteStatementCommand({
        resourceArn,
        secretArn,
        database,
        parameters,
        sql,
        formatRecordsAs: "JSON"
    })

    const result = await rdsClient.send(cmd)
    const parsedRecord = parseInsertResult(result)

    return {
        record: parsedRecord
    }
}

const executeBulkInsert = async (
    sql: string,
    parameterSets: SqlParameter[][],
    dataConn: DataConn
): Promise<DataCreateResponse> => {
    const { resourceArn, secretArn, databaseName: database, rdsClient } = dataConn

    const cmd = new BatchExecuteStatementCommand({
        resourceArn,
        secretArn,
        database,
        parameterSets,
        sql
    })

    const result: BatchExecuteStatementCommandOutput = await rdsClient.send(cmd)

    return {
        recordsCreated: result.updateResults?.length || 0
    }
}

const parseInsertResult = (result: ExecuteStatementCommandOutput): Record<string, any> => {
    if (!result.formattedRecords) {
        return []
    }

    const parsedRecords: Record<string, any>[] = JSON.parse(result.formattedRecords)
        .map(normalizeObj)

    return parsedRecords[0]
}

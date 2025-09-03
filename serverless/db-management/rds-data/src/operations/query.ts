import { ExecuteStatementCommand, ExecuteStatementCommandOutput } from "@aws-sdk/client-rds-data"
import { DataConn, DataQueryResponse, DataRequest } from "../types"
import { normalizeObj } from "./utils"

export const query = async (request: DataRequest, dataConn: DataConn): Promise<DataQueryResponse> => {
    const { resourceArn, secretArn, databaseName: database, rdsClient } = dataConn
    let { sql, parameters } = request

    const hasSelect = sql.toLowerCase().includes('select')
    const hasLimit = sql.toLowerCase().includes('limit')

    const sqlWithCount = addTotalCount(hasSelect, hasLimit, sql)
    console.log("Query to proccess:", sqlWithCount)

    const cmd = new ExecuteStatementCommand({
        resourceArn,
        secretArn,
        database,
        parameters,
        sql: sqlWithCount,
        formatRecordsAs: "JSON"
    })

    const records = await rdsClient.send(cmd)

    return parseResults(hasSelect, hasLimit, records)
}

const addTotalCount = (hasSelect: boolean, hasLimit: boolean, sql: string) => {
    if (hasSelect && hasLimit) {
        const lastFromIndex = sql.toLowerCase().lastIndexOf('from')
        if (lastFromIndex !== -1) {
            sql = sql.slice(0, lastFromIndex) + ', COUNT(*) OVER() as total_count ' + sql.slice(lastFromIndex)
        }
    }
    return sql
}

const parseResults = (hasSelect: boolean, hasLimit: boolean, records: ExecuteStatementCommandOutput): DataQueryResponse => {
    if (!records.formattedRecords) {
        return {
            records: [],
            total: undefined
        }
    }

    const parsedRecords: Record<string, any>[] = JSON.parse(records.formattedRecords)
        .map(normalizeObj)

    const totalCount = (hasSelect && hasLimit && parsedRecords.length > 0)
        ? Number(parsedRecords[0].totalCount) || undefined
        : undefined

    if (hasSelect && hasLimit) {
        parsedRecords.forEach(record => delete record.totalCount)
    }

    return {
        records: parsedRecords ? parsedRecords : [],
        total: totalCount
    }
}

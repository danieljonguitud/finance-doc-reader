import { ExecuteStatementCommand, ExecuteStatementCommandOutput } from "@aws-sdk/client-rds-data";
import { DataConn, DataRequest, DataResponse } from "../types";

export const query = async (request: DataRequest, dataConn: DataConn): Promise<DataResponse> => {
    const { resourceArn, secretArn, databaseName: database, rdsClient } = dataConn;
    let { sql, parameters } = request;

    const hasSelect = sql.toLowerCase().includes('select');
    const hasLimit = sql.toLowerCase().includes('limit');

    const sqlWithCount = addTotalCount(hasSelect, hasLimit, sql);
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

    const { parsedRecords, totalCount } = parseResults(hasSelect, hasLimit, records)

    return {
        records: parsedRecords,
        total: totalCount
    }
}

const addTotalCount = (hasSelect: boolean, hasLimit: boolean, sql: string) => {
    if (hasSelect && hasLimit) {
        const lastFromIndex = sql.toLowerCase().lastIndexOf('from');
        if (lastFromIndex !== -1) {
            sql = sql.slice(0, lastFromIndex) + ', COUNT(*) OVER() as total_count ' + sql.slice(lastFromIndex);
        }
    }
    return sql
}

const parseResults = (hasSelect: boolean, hasLimit: boolean, records: ExecuteStatementCommandOutput) => {
    const parsedRecords: Record<string, any>[] = JSON.parse(records.formattedRecords || '')

    const totalCount = (hasSelect && hasLimit && parsedRecords.length > 0)
        ? parsedRecords[0].total_count || 0
        : 0;

    if (hasSelect && hasLimit) {
        parsedRecords.forEach(record => delete record.total_count);
    }

    return {
        parsedRecords,
        totalCount
    }
}



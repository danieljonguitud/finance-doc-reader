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
    console.log('records', records)

    const { parsedRecords, totalCount } = parseResults(hasSelect, hasLimit, records)
    console.log('parsedRecords', parsedRecords)
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

const toCamelCase = (str: string): string => {
    return str.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
};

const normalizeObj = (record: Record<string, any>): Record<string, any> => {
    const converted: Record<string, any> = {};
    for (const [key, value] of Object.entries(record)) {
        const camelKey = toCamelCase(key);
        if (typeof value === 'string') {
            if (!isNaN(Number(value)) && value !== '') {
                converted[camelKey] = Number(value);
            }
            else if (value === 'true') {
                converted[camelKey] = true;
            }
            else if (value === 'false') {
                converted[camelKey] = false;
            }
            else if (value === 'null') {
                converted[camelKey] = null;
            }
            else {
                converted[camelKey] = value;
            }
        } else {
            converted[camelKey] = value;
        }
    }
    return converted;
};

const parseResults = (hasSelect: boolean, hasLimit: boolean, records: ExecuteStatementCommandOutput) => {
    const parsedRecords: Record<string, any>[] = JSON.parse(records.formattedRecords || '')
        .map(normalizeObj);

    const totalCount = (hasSelect && hasLimit && parsedRecords.length > 0)
        ? Number(parsedRecords[0].totalCount) || undefined
        : undefined;

    if (hasSelect && hasLimit) {
        parsedRecords.forEach(record => delete record.totalCount);
    }

    return {
        parsedRecords,
        totalCount
    }
}



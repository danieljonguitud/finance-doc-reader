import { ExecuteStatementCommand } from "@aws-sdk/client-rds-data";
import { DataConn, DataRequest, DataResponse } from "../types";

export const query = async (request: DataRequest, dataConn: DataConn): Promise<DataResponse> => {
    const { resourceArn, secretArn, databaseName: database, rdsClient } = dataConn;
    const { sql, parameters } = request;

    const cmd = new ExecuteStatementCommand({
        resourceArn,
        secretArn,
        database,
        sql,
        parameters,
        formatRecordsAs: "JSON"
    })

    const result = await rdsClient.send(cmd)

    const parsedResult = JSON.parse(result.formattedRecords || '')

    return {
        records: parsedResult,
        total: 1000
    }
}

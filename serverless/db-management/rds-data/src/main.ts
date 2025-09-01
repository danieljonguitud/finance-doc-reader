import { Context } from "aws-lambda";
import { DataConn, DataRequest, DataResponse } from "./types";
import { query } from "./operations/query";
import { RDSDataClient } from "@aws-sdk/client-rds-data";
import { mapDataError } from "./errors/map-data-error";

const resourceArn = process.env.AURORA_CLUSTER_ARN!
const secretArn = process.env.DATABASE_SECRET_ARN!
const databaseName = process.env.DATABASE_NAME!
const rdsClient = new RDSDataClient()

export const handler = async (event: DataRequest, context: Context): Promise<DataResponse> => {
    const dataConn: DataConn = {
        resourceArn,
        secretArn,
        databaseName,
        rdsClient
    }

    try {
        switch (event.operation) {
            case "query":
                return await query(event, dataConn)
            default:
                throw new Error("400: Operation Not Supported")
        }
    } catch (err: any) {
        console.error(err)
        throw mapDataError(err)
    }
}



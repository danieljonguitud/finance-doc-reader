import { DataRequestError } from "./DataRequestError"

export const mapDataError = (error: any): DataRequestError => {
    const errorName = error.name || error.code || 'UnknownError'

    switch (errorName) {
        case 'DatabaseResumingException':
            return new DataRequestError(
                'DATABASE_RESUMING',
                '503: Database is starting up, please retry in a few seconds',
                error,
                true
            )

        case 'StatementTimeoutException':
            return new DataRequestError(
                'QUERY_TIMEOUT',
                '504: Query timeout - please try simplifying your query or adding more specific filters',
                error,
                false
            )

        case 'DatabaseUnavailableException':
            return new DataRequestError(
                'DATABASE_UNAVAILABLE',
                '503: Database is temporarily unavailable, please retry',
                error,
                true
            )

        case 'InvalidSecretException':
            return new DataRequestError(
                'CONNECTION_ERROR',
                '400: Database connection configuration error',
                error,
                false
            )

        case 'DatabaseNotFoundException':
            return new DataRequestError(
                'DATABASE_NOT_FOUND',
                '400: Database configuration error - database not found',
                error,
                false
            )

        case 'BadRequestException':
            return new DataRequestError(
                'BAD_REQUEST',
                '400: Invalid SQL statement or parameters',
                error,
                false
            )

        case 'DatabaseErrorException':
            return new DataRequestError(
                'SQL_ERROR',
                '400: Error executing SQL statement - please check your query syntax',
                error,
                false
            )

        case 'AccessDeniedException':
        case 'ForbiddenException':
            return new DataRequestError(
                'ACCESS_DENIED',
                '400: Insufficient permissions',
                error,
                false
            )

        case 'HttpEndpointNotEnabledException':
            return new DataRequestError(
                'CONFIGURATION_ERROR',
                '500: Database HTTP endpoint is not enabled',
                error,
                false
            )

        case 'ServiceUnavailableError':
            return new DataRequestError(
                'SERVICE_UNAVAILABLE',
                '503: Database service is temporarily unavailable',
                error,
                true
            )

        case 'InternalServerErrorException':
            return new DataRequestError(
                'INTERNAL_ERROR',
                '500: Internal database error, please retry',
                error,
                true
            )

        default:
            return new DataRequestError(
                'UNKNOWN_ERROR',
                '400: An unexpected error occurred while processing your request',
                error,
                false
            )
    }
}

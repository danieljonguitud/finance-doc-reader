export class DataRequestError extends Error {
    public readonly code: string;
    public readonly retryable: boolean;
    public readonly originalError: Error;

    constructor(code: string, message: string, originalError: Error, retryable: boolean = false) {
        super(message);
        this.name = 'DataRequestError';
        this.code = code;
        this.retryable = retryable;
        this.originalError = originalError;
    }
}

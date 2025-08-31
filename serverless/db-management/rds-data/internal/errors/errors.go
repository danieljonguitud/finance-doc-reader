package errors

type LambdaError struct {
	ErrorMessage string `json:"errorMessage"`
}

func (e *LambdaError) Error() string {
	return e.ErrorMessage
}

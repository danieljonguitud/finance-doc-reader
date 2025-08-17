package mistralrequest

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

type OCRRequest struct {
	Model              string   `json:"model"`
	Document           Document `json:"document"`
	IncludeImageBase64 bool     `json:"include_image_base64"`
}

type Document struct {
	Type        string `json:"type"`
	DocumentURL string `json:"document_url"`
}

type MistralOCRResponse struct {
	Pages []Page `json:"pages"`
}

type Page struct {
	Index    int    `json:"index"`
	Markdown string `json:"markdown"`
}

type APIError struct {
	StatusCode int
	Message    string
}

func (e *APIError) Error() string {
	return fmt.Sprintf("API error %d: %s", e.StatusCode, e.Message)
}

func RequestPDFToMD(ctx context.Context, pdfStr string) (string, error) {
	// Input validation
	if pdfStr == "" {
		return "", fmt.Errorf("pdfStr cannot be empty")
	}

	url := os.Getenv("MISTRAL_API_ENDPOINT")
	if url == "" {
		return "", fmt.Errorf("MISTRAL_API_ENDPOINT environment variable not set")
	}

	apiKey := os.Getenv("MISTRAL_API_KEY")
	if apiKey == "" {
		return "", fmt.Errorf("MISTRAL_API_KEY environment variable not set")
	}

	requestData := OCRRequest{
		Model: "mistral-ocr-latest",
		Document: Document{
			Type:        "document_url",
			DocumentURL: fmt.Sprintf("data:application/pdf;base64,%s", pdfStr),
		},
		IncludeImageBase64: false,
	}

	jsonData, err := json.Marshal(requestData)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request data: %w", err)
	}

	client := &http.Client{
		Timeout: 30 * time.Second,
	}
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", fmt.Errorf("failed to create HTTP request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", apiKey))

	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response body: %w", err)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", &APIError{
			StatusCode: resp.StatusCode,
			Message:    string(body),
		}
	}

	var mistralResponse MistralOCRResponse
	if err := json.Unmarshal(body, &mistralResponse); err != nil {
		return "", fmt.Errorf("failed to parse response: %w", err)
	}

	if len(mistralResponse.Pages) == 0 {
		return "", fmt.Errorf("no pages found in OCR response")
	}

	return combinePages(&mistralResponse), nil
}

func combinePages(response *MistralOCRResponse) string {
	if len(response.Pages) == 0 {
		return ""
	}

	var builder strings.Builder

	for i, page := range response.Pages {
		if i > 0 {
			builder.WriteString("\n")
		}
		builder.WriteString(page.Markdown)
	}

	return builder.String()
}

package mistralRequest

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
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

func RequestPDFtoMD(pdfStr string) (string, error) {
	url := os.Getenv("MISTRAL_API_ENDPOINT")
	apiKey := os.Getenv("MISTRAL_API_KEY")

	if apiKey == "" {
		return "", errors.New("MISTRAL_API_KEY environment variable not set")
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
		log.Printf("Error Marshalling: %s", err)
		return "", errors.New("Error marshalling request data")
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		log.Printf("Error Creating Mistral request: %s", err)
		return "", errors.New("Create Mistral Request Failed")
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", apiKey))

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("Error during Mistral request: %s", err)
		return "", errors.New("Error Mistral request")
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("Error reding response body: %s", err)
		return "", errors.New("Error reading response body")
	}

	if resp.StatusCode != http.StatusOK {
		log.Printf("Request Status Error: %s", resp.Status)
		return "", errors.New("Request Status Error")
	}

	var mistralResponse MistralOCRResponse
	err = json.Unmarshal(body, &mistralResponse)
	if err != nil {
		log.Printf("Request parsing response: %s", err)
		return "", errors.New("Error parsing response")
	}

	return combinePages(&mistralResponse), nil
}

func combinePages(body *MistralOCRResponse) string {
	var builder strings.Builder
	for i, page := range body.Pages {
		if i > 0 {
			builder.WriteString("\n")
		}
		builder.WriteString(page.Markdown)
	}

	return builder.String()
}

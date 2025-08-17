package s3Helper

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"log"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

var (
	s3Client *s3.Client
)

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		panic(fmt.Sprintf("failed loading config, %v", err))
	}
	s3Client = s3.NewFromConfig(cfg)
}

func RetrieveFile(ctx context.Context, bucket string, key string) (string, error) {
	object, err := s3Client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: &bucket,
		Key:    &key,
	})

	if err != nil {
		log.Printf("Error during GetObject operation: %s", err)
		return "", errors.New("Error during GetObject operation")
	}
	defer object.Body.Close()

	body, err := io.ReadAll(object.Body)
	if err != nil {
		log.Printf("Error during reading object: %s", err)
		return "", errors.New("Error during reading object")
	}

	encoded := base64.StdEncoding.EncodeToString(body)

	return encoded, nil
}

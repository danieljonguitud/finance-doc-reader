package s3helper

import (
	"context"
	"encoding/base64"
	"fmt"
	"io"

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
		return "", fmt.Errorf("failed to get S3 object s3://%s/%s: %w", bucket, key, err)
	}
	defer object.Body.Close()

	body, err := io.ReadAll(object.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read S3 object s3://%s/%s: %w", bucket, key, err)
	}

	if len(body) == 0 {
		return "", fmt.Errorf("S3 object s3://%s/%s is empty", bucket, key)
	}

	encoded := base64.StdEncoding.EncodeToString(body)
	return encoded, nil
}

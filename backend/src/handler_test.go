package main

import (
	"context"
	"os"
	"testing"

	"github.com/ahmedakef/gotutor/backend/src/cache"
	"github.com/ahmedakef/gotutor/backend/src/db"
	"github.com/ahmedakef/gotutor/serialize"
	"github.com/rs/zerolog"
)

var _sourceCode = "package main\nimport \"fmt\"\nfunc main() {fmt.Println(\"Hello\")}"

func TestGetExecutionSteps(t *testing.T) {

	tests := []struct {
		name           string
		req            GetExecutionStepsRequest
		setupCache     func(cache cache.LRUCache)
		expectedStdOut string
		expectedStdErr string
		expectError    bool
	}{
		{
			name: "CacheHit",
			req: GetExecutionStepsRequest{
				SourceCode: _sourceCode,
			},
			setupCache: func(cache cache.LRUCache) {
				expectedResponse := serialize.ExecutionResponse{
					StdOut: "cached output",
				}
				cache.Set(_sourceCode, expectedResponse)
			},
			expectedStdOut: "cached output",
			expectError:    false,
		},
		{
			name: "CacheMiss",
			req: GetExecutionStepsRequest{
				SourceCode: _sourceCode,
			},
			setupCache: func(cache cache.LRUCache) {
			},
			expectedStdOut: "Hello\n",
			expectedStdErr: "",
			expectError:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			logger := zerolog.New(os.Stdout)
			cache := cache.NewLRUCache(_maxCacheSize, _maxCacheItems, _cacheTTL)
			tmpDir, err := os.MkdirTemp("", "gotutor-test-db-*")
			if err != nil {
				t.Fatalf("failed to create temp dir: %v", err)
			}
			defer os.RemoveAll(tmpDir)
			db, err := db.New(tmpDir + "/gotutor.db")
			if err != nil {
				t.Fatalf("failed to create database: %v", err)
			}
			defer db.Close()
			handler := newHandler(logger, cache, db)
			tt.setupCache(cache)

			ctx := context.Background()
			resp, err := handler.GetExecutionSteps(ctx, tt.req)
			if tt.expectError {
				if err == nil {
					t.Fatalf("expected error, got nil")
				}
			} else {
				if err != nil {
					t.Fatalf("expected no error, got %v", err)
				}
				if resp.StdOut != tt.expectedStdOut {
					t.Fatalf("expected %v, got %v", tt.expectedStdOut, resp.StdOut)
				}
				if resp.StdErr != tt.expectedStdErr {
					t.Fatalf("expected %v, got %v", tt.expectedStdErr, resp.StdErr)
				}
			}
		})
	}
}

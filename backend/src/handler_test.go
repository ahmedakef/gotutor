package main

import (
	"context"
	"os"
	"testing"

	"github.com/ahmedakef/gotutor/backend/src/cache"
	"github.com/ahmedakef/gotutor/serialize"
	"github.com/rs/zerolog"
)

var _sourceCode = "package main\nimport \"fmt\"\nfunc main() {fmt.Println(\"Hello\")}"

func TestGetExecutionSteps(t *testing.T) {

	tests := []struct {
		name           string
		req            GetExecutionStepsRequest
		setupCache     func(cache cache.LRUCache)
		expectedOutput string
		expectError    bool
	}{
		{
			name: "CacheHit",
			req: GetExecutionStepsRequest{
				SourceCode: _sourceCode,
			},
			setupCache: func(cache cache.LRUCache) {
				expectedResponse := serialize.ExecutionResponse{
					Output: "cached output",
				}
				cache.Set(_sourceCode, expectedResponse)
			},
			expectedOutput: "cached output",
			expectError:    false,
		},
		{
			name: "CacheMiss",
			req: GetExecutionStepsRequest{
				SourceCode: _sourceCode,
			},
			setupCache: func(cache cache.LRUCache) {
			},
			expectedOutput: "Hello\n",
			expectError:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			logger := zerolog.New(os.Stdout)
			cache := cache.NewLRUCache(_maxCacheSize, _maxCacheItems, _cacheTTL)
			handler := newHandler(logger, cache)
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
				if resp.Output != tt.expectedOutput {
					t.Fatalf("expected %v, got %v", tt.expectedOutput, resp.Output)
				}
			}
		})
	}
}

package controller

import (
	"context"
	"errors"
	"os"
	"testing"

	"github.com/ahmedakef/gotutor/backend/src/cache"
	"github.com/ahmedakef/gotutor/backend/src/db"
	"github.com/ahmedakef/gotutor/serialize"
	"github.com/rs/zerolog"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var _sourceCode = "package main\nimport \"fmt\"\nfunc main() {fmt.Println(\"Hello\")}"

func TestGetExecutionSteps(t *testing.T) {

	tests := []struct {
		name           string
		sourceCode     string
		setupCache     func(cache cache.LRUCache)
		expectedStdOut string
		expectedStdErr string
		expectError    bool
	}{
		{
			name:       "CacheHit",
			sourceCode: _sourceCode,
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
			name:       "CacheMiss",
			sourceCode: _sourceCode,
			setupCache: func(cache cache.LRUCache) {
			},
			expectedStdOut: "Hello\n",
			expectedStdErr: "",
			expectError:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tp := newTestParams(t)
			defer os.RemoveAll(tp.tmpDir)
			controller := NewController(tp.logger, tp.cache, tp.db)
			tt.setupCache(tp.cache)

			ctx := context.Background()
			resp, err := controller.GetExecutionSteps(ctx, tt.sourceCode)
			if tt.expectError {
				if err == nil {
					t.Fatalf("expected error, got nil")
				}
				require.Error(t, err)
			} else {
				require.NoError(t, err)
				assert.Equal(t, tt.expectedStdOut, resp.StdOut)
				assert.Equal(t, tt.expectedStdErr, resp.StdErr)
			}
		})
	}
}

func TestCompile(t *testing.T) {
	tests := []struct {
		name           string
		sourceCode     string
		expectedStdOut string
		expectError    error
	}{
		{
			name:           "successful compilation",
			sourceCode:     _sourceCode,
			expectedStdOut: "",
			expectError:    nil,
		},
		{
			name:           "failed compilation",
			sourceCode:     "package main\nfunc main() {fmt.Println(\"Hello\")}",
			expectedStdOut: "",
			expectError:    errors.New("./prog.go:2:14: undefined: fmt\n"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tp := newTestParams(t)
			defer os.RemoveAll(tp.tmpDir)
			controller := NewController(tp.logger, tp.cache, tp.db)

			resp, err := controller.Compile(context.Background(), tt.sourceCode)
			if tt.expectError != nil {
				assert.Error(t, err)
				assert.Equal(t, tt.expectError, err)
			} else {
				require.NoError(t, err)
				assert.Equal(t, tt.expectedStdOut, resp.StdOut)
			}
		})
	}
}

type testParams struct {
	db     *db.DB
	cache  cache.LRUCache
	logger zerolog.Logger
	tmpDir string
}

func newTestParams(t *testing.T) testParams {
	tmpDir, err := os.MkdirTemp("", "gotutor-test-db-*")
	require.NoError(t, err)
	db, err := db.New(tmpDir + "/gotutor.db")
	require.NoError(t, err)
	return testParams{
		db:     db,
		cache:  cache.NewLRUCache(1024*100*100, 100, 0),
		logger: zerolog.New(os.Stdout),
		tmpDir: tmpDir,
	}
}

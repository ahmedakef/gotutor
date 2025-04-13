package db

import (
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"os"
	"path/filepath"
	"time"

	bolt "go.etcd.io/bbolt"
)

const (
	CallsBucket       = "Calls"
	GetExecutionSteps = "GetExecutionSteps"
	Format            = "Format"
	_sourceCodeBucket = "SourceCode"
	_codeKey          = "code"
	_updatedAtKey     = "updated_at"
)

type DB struct {
	*bolt.DB
}

// New creates a new DB instance
func New(dbPath string) (*DB, error) {

	// Ensure the directory exists
	dbDir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dbDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create database directory: %w", err)
	}

	bdb, err := bolt.Open(dbPath, 0600, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	db := &DB{bdb}
	if err := db.ensureBuckets([]string{_sourceCodeBucket, CallsBucket}); err != nil {
		return nil, err
	}

	return db, nil
}

func (db *DB) ensureBuckets(buckets []string) error {
	return db.Update(func(tx *bolt.Tx) error {
		for _, bucket := range buckets {
			_, err := tx.CreateBucketIfNotExists([]byte(bucket))
			if err != nil {
				return fmt.Errorf("failed to create bucket %s: %w", bucket, err)
			}
		}
		return nil
	})
}

// IncrementCallCounter increments the counter for API calls
func (db *DB) IncrementCallCounter(endpoint string) (uint64, error) {
	var counter uint64
	err := db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte(CallsBucket))
		if b == nil {
			return fmt.Errorf("bucket %s not found", CallsBucket)
		}
		// Get or create sequence for this endpoint
		calls := b.Get([]byte(endpoint))
		if calls == nil {
			// Initialize sequence to 0 if it doesn't exist
			calls = uint64ToBytes(0)
		}
		counter = binary.BigEndian.Uint64(calls) + 1
		if err := b.Put([]byte(endpoint), uint64ToBytes(counter)); err != nil {
			return fmt.Errorf("failed to update sequence: %w", err)
		}
		return nil
	})
	return counter, err
}

func uint64ToBytes(counter uint64) []byte {
	b := make([]byte, 8)
	binary.BigEndian.PutUint64(b, counter)
	return b
}

// SaveSourceCode stores the source code with its hash as the key
func (db *DB) SaveSourceCode(sourceCode string) error {
	return db.Update(func(tx *bolt.Tx) error {
		sourceCodeBucket := tx.Bucket([]byte(_sourceCodeBucket))
		if sourceCodeBucket == nil {
			return fmt.Errorf("bucket %s not found", _sourceCodeBucket)
		}

		hash := sha256.Sum256([]byte(sourceCode))
		hashSlice := hash[:]
		codeBucket, err := sourceCodeBucket.CreateBucketIfNotExists(hashSlice)
		if err != nil {
			return fmt.Errorf("failed to create bucket: %w", err)
		}
		// Check if source code already exists
		if v := codeBucket.Get([]byte(_codeKey)); v != nil {
			return nil
		}

		err = codeBucket.Put([]byte(_codeKey), []byte(sourceCode))
		if err != nil {
			return fmt.Errorf("failed to save source code: %w", err)
		}

		return codeBucket.Put([]byte(_updatedAtKey), []byte(time.Now().String()))
	})
}

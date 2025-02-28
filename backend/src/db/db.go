package db

import (
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"os"
	"path/filepath"

	bolt "go.etcd.io/bbolt"
)

const (
	_callsBucket      = "GetExecutionStepsCalls"
	_sourceCodeBucket = "SourceCode"
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
	if err := db.createBuckets([]string{_sourceCodeBucket, _callsBucket}); err != nil {
		return nil, err
	}

	return db, nil
}

func (db *DB) createBuckets(buckets []string) error {
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
func (db *DB) IncrementCallCounter() (uint64, error) {
	var counter uint64
	err := db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte(_callsBucket))
		if b == nil {
			return fmt.Errorf("bucket %s not found", _callsBucket)
		}
		var err error
		counter, err = b.NextSequence()
		if err != nil {
			return err
		}
		return b.Put([]byte(_callsBucket), uint64ToBytes(counter))
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
		b := tx.Bucket([]byte(_sourceCodeBucket))
		if b == nil {
			return fmt.Errorf("bucket %s not found", _sourceCodeBucket)
		}

		hash := sha256.Sum256([]byte(sourceCode))
		hashSlice := hash[:]
		// Check if source code already exists
		if v := b.Get(hashSlice); v != nil {
			return nil
		}

		return b.Put(hashSlice, []byte(sourceCode))
	})
}

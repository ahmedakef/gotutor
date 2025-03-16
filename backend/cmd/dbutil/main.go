package main

import (
	"encoding/binary"
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/ahmedakef/gotutor/backend/src/db"
	bolt "go.etcd.io/bbolt"
)

const (
	_callsBucket      = "GetExecutionStepsCalls"
	_sourceCodeBucket = "SourceCode"
	_codeKey          = "code"
	_updatedAtKey     = "updated_at"
)

func main() {
	dbPath := flag.String("db", "gotutor.db", "Path to the database file")
	flag.Parse()

	if _, err := os.Stat(*dbPath); os.IsNotExist(err) {
		log.Fatalf("Database file not found: %s", *dbPath)
	}

	db, err := db.New(*dbPath)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}
	defer db.Close()

	err = db.View(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte(_sourceCodeBucket))
		if b == nil {
			return fmt.Errorf("SourceCode bucket not found")
		}

		fmt.Println("Listing all saved source code files:")
		fmt.Println("=====================================")

		count := 0
		err := b.ForEachBucket(func(k []byte) error {
			codeBucket := b.Bucket(k)
			code := codeBucket.Get([]byte(_codeKey))
			updatedAt := codeBucket.Get([]byte(_updatedAtKey))
			count++
			fmt.Printf("\nFile %d:\n", count)
			fmt.Println("Hash:", fmt.Sprintf("%x", k))
			fmt.Println("Content:")
			fmt.Println("----------------------------------------")
			fmt.Println(string(code))
			fmt.Println("Updated at:", string(updatedAt))
			fmt.Println("----------------------------------------")
			return nil
		})
		if err != nil {
			return fmt.Errorf("failed to list source code files: %w", err)
		}
		callsBuckets := tx.Bucket([]byte(_callsBucket))
		calls := callsBuckets.Get([]byte(_callsBucket))
		fmt.Println("total Calls:", bytesToUint64(calls))
		return nil
	})

	if err != nil {
		log.Fatal(err)
	}
}

func bytesToUint64(b []byte) uint64 {
	return binary.BigEndian.Uint64(b)
}

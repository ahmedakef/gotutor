package main

import (
	"encoding/binary"
	"flag"
	"fmt"
	"log"
	"os"
	"sort"

	dbpkg "github.com/ahmedakef/gotutor/backend/src/db"
	bolt "go.etcd.io/bbolt"
)

type Source struct {
	Hash      string
	Code      string
	UpdatedAt string
}

type Result struct {
	sources []Source
	calls   Calls
}
type Calls struct {
	getExecutionSteps uint64
	format            uint64
	fixCode           uint64
}

func main() {
	result, err := getDBData()
	if err != nil {
		log.Fatal(err)
	}
	// Sort sources by UpdatedAt in descending order
	sort.Slice(result.sources, func(i, j int) bool {
		return result.sources[i].UpdatedAt < result.sources[j].UpdatedAt
	})

	printResults(result)
}

func getDBData() (Result, error) {
	dbPath := flag.String("db", "gotutor.db", "Path to the database file")
	flag.Parse()

	if _, err := os.Stat(*dbPath); os.IsNotExist(err) {
		log.Fatalf("Database file not found: %s", *dbPath)
	}

	db, err := dbpkg.New(*dbPath)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}
	defer db.Close()

	var sources []Source
	var getExecutionSteps uint64
	var format uint64
	var fixCode uint64

	err = db.View(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte(dbpkg.SourceCodeBucket))
		if b == nil {
			return fmt.Errorf("SourceCode bucket not found")
		}

		err := b.ForEachBucket(func(k []byte) error {
			codeBucket := b.Bucket(k)
			code := codeBucket.Get([]byte(dbpkg.CodeKey))
			updatedAt := codeBucket.Get([]byte(dbpkg.UpdatedAtKey))
			sources = append(sources, Source{
				Hash:      fmt.Sprintf("%x", k),
				Code:      string(code),
				UpdatedAt: string(updatedAt),
			})
			return nil
		})
		if err != nil {
			return fmt.Errorf("failed to list source code files: %w", err)
		}
		callsBuckets := tx.Bucket([]byte(dbpkg.CallsBucket))
		getExecutionSteps = bytesToUint64(callsBuckets.Get([]byte(dbpkg.GetExecutionSteps)))
		format = bytesToUint64(callsBuckets.Get([]byte(dbpkg.Format)))
		fixCode = bytesToUint64(callsBuckets.Get([]byte(dbpkg.FixCode)))
		return nil
	})

	if err != nil {
		return Result{}, err
	}

	return Result{
		sources: sources,
		calls:   Calls{getExecutionSteps: getExecutionSteps, format: format, fixCode: fixCode},
	}, nil
}

func printResults(result Result) {
	fmt.Println("Listing all saved source code files:")
	fmt.Println("=====================================")

	for i, source := range result.sources {
		fmt.Println("Number:", i)
		fmt.Println("Hash:", fmt.Sprintf("%x", source.Hash))
		// Take only the first 19 characters of the timestamp (YYYY-MM-DD HH:MM:SS)
		if len(source.UpdatedAt) >= 19 {
			fmt.Println("Updated at:", source.UpdatedAt[:19])
		} else {
			fmt.Println("Updated at:", source.UpdatedAt)
		}
		fmt.Println("Content:")
		fmt.Println("----------------------------------------")
		fmt.Println(source.Code)
		fmt.Println("----------------------------------------")
	}
	fmt.Println("Calls:")
	fmt.Println("GetExecutionSteps:", result.calls.getExecutionSteps)
	fmt.Println("Format:", result.calls.format)
	fmt.Println("FixCode:", result.calls.fixCode)
}

func bytesToUint64(b []byte) uint64 {
	return binary.BigEndian.Uint64(b)
}

package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/ahmedakef/gotutor/backend/src/db"
	bolt "go.etcd.io/bbolt"
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
		b := tx.Bucket([]byte("SourceCode"))
		if b == nil {
			return fmt.Errorf("SourceCode bucket not found")
		}

		fmt.Println("Listing all saved source code files:")
		fmt.Println("=====================================")

		count := 0
		return b.ForEach(func(k, v []byte) error {
			count++
			fmt.Printf("\nFile %d:\n", count)
			fmt.Println("Hash:", fmt.Sprintf("%x", k))
			fmt.Println("Content:")
			fmt.Println("----------------------------------------")
			fmt.Println(string(v))
			fmt.Println("----------------------------------------")
			return nil
		})
	})

	if err != nil {
		log.Fatal(err)
	}
}

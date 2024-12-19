package main

import (
	"fmt"
	"sync"
	"time"
)

var packageVar = "packageVar"

func main() {
	var wg sync.WaitGroup
	hello("ahmed")
	fmt.Println(packageVar)

	wg.Add(2) // Wait for two workers

	go work(1, &wg)
	go work(2, &wg)

	fmt.Println("Main function waiting for workers to finish")

	wg.Wait() // Wait for all workers to finish
}

func hello(personName string) {
	greating := "Hello, World!"
	fmt.Printf("%s %s", greating, personName)
}

func work(i int, wg *sync.WaitGroup) {
	startWord := fmt.Sprintf("Worker %d starting", i)
	fmt.Println(startWord)
	time.Sleep(5 * time.Second)
	endWord := fmt.Sprintf("Worker %d done", i)
	fmt.Println(endWord)
	wg.Done()
}

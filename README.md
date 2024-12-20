# GoTutor

GoTutor is a project aimed at capturing the execution steps of a Go program by interacting with the Delve debugger server. It retrieves variable values and stack information at each Go statement.

## Features

- Captures variable values and stack information at each Go statement
- In the future, I plan to extend this project to visualize the execution steps, similar to [Python Tutor](https://pythontutor.com/).

## Limitations
Currently, the project has limitations when handling multiple goroutines. When using `next` or `step` on a single goroutine, all goroutines progress, making it difficult to capture the state of other goroutines. This issue is documented in [Delve Issue #1529](https://github.com/go-delve/delve/issues/1529).
Attempts to create a client for each goroutine and step through them individually have been unsuccessful and have caused runtime errors in the Delve server.

## Usage
the commands follow `dlv` cli terminology

### exec
```
gotutor exec binary_path
```
run delve server with the binary that `gotutor` will interact with to get execution steps

### debug
```
gotutor debug
```
build the go module in the current directory then contine the same as exec

### connect
```
gotutor connect delve_server_address
```
connect to already running delve server

the execution steps will be written to `steps` file in the current direcotry

### Prerequisites

- Go (latest version)
- Delve debugger

### Installation

```
go install github.com/ahmedakef/gotutor@latest
```


## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License.

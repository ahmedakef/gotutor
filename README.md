[![Ceasefire Now](https://badge.techforpalestine.org/default)](https://techforpalestine.org/learn-more)
# GoTutor

GoTutor is a project aimed at capturing the execution steps of a Go program by interacting with the Delve debugger server. It retrieves variable values and stack information of all running Goroutines at each Go statement.

https://gotutor.dev/

## Features

- Capture running Goroutines and its stack frames state at each Go statement of the main Goroutine.
- Interactive online Debugging tool: https://gotutor.dev/.

## Architecture
The project is split into three components:
- CLI tool: that takes a go program and produces `output/steps.json` file which represent the execution steps of the program (exists under `.`)
- backend: run the CLI tool for the given program and return the execution steps (exists under `backend/`)
- frontend: the frontend of https://gotutor.dev/ which is build using [elm-lang](https://elm-lang.org/) (exists under `frontend/`)

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

the execution steps will be written to `steps.json` file in the current direcotry

### Prerequisites

- Go (latest version)
- Delve debugger

### Installation

```
go install github.com/ahmedakef/gotutor@latest
```

## docker

```
docker build -t gotutor . # or directly use ahmedakef/gotutor image to download it from docker hub
docker run --rm -v $(pwd)/example/main.go:/data/main.go -v $(pwd)/output/:/root/output gotutor debug /data/main.go
```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License.


## Give a Star! ⭐

If you like this project or are using it to learn or start your own solution, give it a star to get updates on new releases. Your support matters!

## Buy me a coffee

<a href='https://ko-fi.com/M4M319RW5Y' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi6.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>

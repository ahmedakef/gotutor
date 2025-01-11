# Hello world - Go example

backend service that received the code and produce the execution steps built using Restate.

You can run locally with `go run .` and register to Restate with
`restate dep add http://localhost:9080`.
Then you can invoke with `http POST localhost:8080/Handler/GetExecutionSteps source_code="$(cat main.go)"`.

You can build a docker image using [ko](https://github.com/ko-build/ko):
`ko build --platform=all`

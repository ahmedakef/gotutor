build:
	go build -o main
	docker build -t gotutor .
	docker tag gotutor ahmedakef/gotutor:latest
updateExample: build
	go build  -gcflags='all=-N -l' -o example/source_debug example/main.go
	./main exec example/source_debug
	jq . steps.json > steps_formatted.json
	mv steps_formatted.json steps.json
	cp steps.json frontend/src/initialProgram
	cp example/main.go frontend/src/initialProgram/main.txt

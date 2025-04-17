build:
	go build -o main
	docker build -t ahmedakef/gotutor:latest -t gotutor .
	# docker push ahmedakef/gotutor:latest

go-build:
	go build -o main

updateExample: go-build
	go build  -gcflags='all=-N -l' -o example/source_debug example/main.go
	./main exec example/source_debug
	jq . output/steps.json > output/steps_formatted.json
	mv output/steps_formatted.json output/steps.json
	cp output/steps.json frontend/src/initialProgram
	cp example/main.go frontend/src/initialProgram/main.txt
	cp example/main.go backend/load-tests/main.txt

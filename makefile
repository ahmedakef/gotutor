build:
	go build -o main
	docker build -t gotutor .
	docker tag gotutor ahmedakef/gotutor:latest
	# docker push ahmedakef/gotutor:latest
updateExample: build
	go build  -gcflags='all=-N -l' -o example/source_debug example/main.go
	./main exec example/source_debug
	jq . output/steps.json > output/steps_formatted.json
	mv output/steps_formatted.json output/steps.json
	cp output/steps.json frontend/src/initialProgram
	cp example/main.go frontend/src/initialProgram/main.txt
	cp example/main.go backend/examples/gotutor.txt
	cp example/main.go backend/load-tests/main.txt

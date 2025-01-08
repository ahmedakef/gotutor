build:
	go build -o main
updateExample:
	go build -o main
	go build  -gcflags='all=-N -l' -o example/source_debug example/main.go
	./main exec example/source_debug
	jq . steps.json > steps_formatted.json
	mv steps_formatted.json steps.json
	cp steps.json frontend/example
	cp example/main.go frontend/example.txt

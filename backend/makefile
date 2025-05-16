ifeq ($(shell uname), Darwin)
	GO_PATH := /opt/homebrew/Cellar/go/1.24.0/libexec/.
else
	GO_PATH := /usr/local/go/.
endif

build:
	go build -o backend ./src
run: build
	./backend

faketime:
	sudo mkdir -p /usr/local/go-faketime
	sudo cp -r $(GO_PATH) /usr/local/go-faketime
	mkdir -p ~/gocache
	GOCACHE=~/gocache /usr/local/go-faketime/bin/go install --tags=faketime std

deploy: faketime build
	sudo cp deployment/nginx/nginx.conf /etc/nginx/nginx.conf
	sudo cp deployment/nginx/sites-enabled/gotutor.conf /etc/nginx/sites-enabled/gotutor.conf
	sudo cp deployment/systemd/system/gotutor.service /etc/systemd/system/gotutor.service
	sudo systemctl daemon-reload
	sudo systemctl enable nginx
	sudo systemctl restart gotutor

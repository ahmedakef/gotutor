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

gVisor:
	sudo mv deployment/docker_daemon.json /etc/docker/daemon.json
	sudo curl -L -o /var/lib/docker/runsc https://storage.googleapis.com/gvisor/releases/release/latest/x86_64/runsc
	sudo chmod +x /var/lib/docker/runsc
	sudo systemctl reload docker.service

deploy: faketime gVisor build
	sudo cp deployment/nginx/nginx.conf /etc/nginx/nginx.conf
	sudo cp deployment/nginx/sites-enabled/gotutor.conf /etc/nginx/sites-enabled/gotutor.conf
	sudo cp deployment/systemd/system/gotutor.service /etc/systemd/system/gotutor.service
	sudo systemctl daemon-reload
	sudo systemctl enable nginx
	sudo systemctl restart gotutor
	# check the logs with sudo journalctl -u gotutor.service -n 10 -f

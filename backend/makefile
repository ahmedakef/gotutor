build:
	go build

deploy: build
	sudo cp deployment/nginx/nginx.conf /etc/nginx/nginx.conf
	sudo cp deployment/nginx/sites-available/gotutor.conf /etc/nginx/sites-available/gotutor.conf
	sudo cp deployment/systemd/system/gotutor.service /etc/systemd/system/gotutor.service
	sudo systemctl daemon-reload
	sudo systemctl enable nginx
	sudo systemctl restart gotutor

#!/bin/bash
sudo yum install -y git
sudo yum install -y go
git clone https://github.com/ahmedakef/gotutor
cd gotutor/backend
go build
sudo cp deployment/systemd/system/gotutor.service /etc/systemd/system/gotutor.service
sudo systemctl enable gotutor
sudo systemctl start gotutor


# let's encrypt
sudo amazon-linux-extras install epel
sudo yum install certbot-nginx

# nginx
# we need to make cloudflare SSL config to be Full not Full (strict) to avoid errors
sudo cp deployment/nginx/nginx.conf /etc/nginx/nginx.conf
sudo cp deployment/nginx/sites-enabled/gotutor.conf /etc/nginx/sites-enabled/gotutor.conf
sudo systemctl enable nginx
sudo systemctl start nginx

# docker
# https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-docker.html
sudo yum install -y docker
sudo usermod -a -G docker ec2-user # Add the ec2-user to the docker group so that you can run Docker commands without using sudo.
sudo systemctl enable docker
sudo systemctl start docker

# ssh
sudo mkdir -p /etc/systemd/system/sshd.service.d
sudo cp deployment/systemd/system/sshd.service.d/priority.conf /etc/systemd/system/sshd.service.d/priority.conf
sudo systemctl daemon-reload
sudo systemctl restart sshd

# the letsencrypt cron job: 0 3 5 * * certbot renew --quiet && systemctl restart nginx

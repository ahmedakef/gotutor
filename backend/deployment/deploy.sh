#!/bin/bash
sudo yum install -y git
sudo yum install -y go
git clone https://github.com/ahmedakef/gotutor
cd gotutor/backend
go build
sudo cp deployment/systemd/system/gotutor.service /etc/systemd/system/gotutor.service
sudo systemctl enable gotutor

# let's encrypt
sudo amazon-linux-extras install epel
sudo yum install certbot-nginx

# nginx
sudo cp deployment/nginx/nginx.conf /etc/nginx/nginx.conf
sudo cp deployment/nginx/sites-available/gotutor.conf /etc/nginx/sites-available/gotutor.conf
sudo ln -s /etc/nginx/sites-available/gotutor /etc/nginx/sites-enabled/

# docker
# https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-docker.html
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user # Add the ec2-user to the docker group so that you can run Docker commands without using sudo.



# the letsencrypt cron job: 0 3 5 * * certbot renew --quiet && systemctl restart nginx

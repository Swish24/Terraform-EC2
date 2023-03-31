#!/bin/bash

# Perform updates to the instances
dnf update -y
# Install docker
dnf install docker.x86_64 -y
# Start the docker service
service docker start
# Add the EC2 User as administrator so we do not need to run sudo
usermod -a -G docker ec2-user
# Enable docker to run as a service 
systemctl enable docker.service
systemctl enable containerd.service
# Run docker command to install nginx as our webserver
# https://docs.linuxserver.io/images/docker-nginx
docker run -d \
--name=nginx \
-e PUID=1000 \
-e PGID=1000 \
-e TZ=America/Los_Angeles \
-p 80:80 \
-p 443:443 \
-v /mnt/nginx/config:/config \
--restart unless-stopped \
lscr.io/linuxserver/nginx:latest
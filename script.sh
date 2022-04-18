#!/bin/bash

#Detecting OS
os_name=$(hostnamectl | grep "Operating System:" | awk '{print $3,$4,$5}')
echo "Detected $os_name"

desired_os="Amazon Linux 2"
if [[ "$desired_os" = "$os_name" ]]; then
echo "" > /dev/null
else
echo "The OS distribution does not matching!...Exiting now"
exit
fi

#Checking Docker is installed or not!
if [[ -x "$(command -v docker)" ]];then
echo "Detected $(docker --version | awk '{print $1,$2,$3}' | sed 's/\(.*\),/\1 /')"
else
echo "No Docker version found!... Installing Docker..."
sudo yum install docker -y &> /dev/null
sudo systemctl start docker.service
sudo systemctl enable docker.service &> /dev/null
fi

#Checking Docker-Compose is installed or not!
if [[ -x "$(command -v docker-compose)" ]]; then
echo "Detected $(docker-compose --version)"
else
echo "Docke-Compose was not found...Installing Docker-Compose"
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose &> /dev/null
sudo chmod +x /usr/local/bin/docker-compose
fi

#Creating project directory
echo "Creating project directory..."
mkdir /home/ec2-user/ipgeo-caching
mkdir /home/ec2-user/ipgeo-caching/nginx 
mkdir /home/ec2-user/ipgeo-caching/nginx/logs
mkdir /home/ec2-user/ipgeo-caching/certs
cd /home/ec2-user/ipgeo-caching/

#Reading domain name and adding it to Nginx conf
echo -n "Enter the domain name: "
read domain
echo "Building Nginx conf file..."
cat <<EOF > /home/ec2-user/ipgeo-caching/nginx/nginx.conf
upstream ipgeo {
        server ipgeo-frontend1:8081;
        server ipgeo-frontend2:8082;
        server ipgeo-frontend3:8083;
}

server {
        listen 80;
        server_name $domain;
        location / {
            return 301 https://$domain$request_uri;
        }
}
server {
        listen 443 ssl;
        server_name $domain;

        ssl_certificate /etc/ssl/certs/site.crt;
        ssl_certificate_key /etc/ssl/certs/site.key;

        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;

        location / {
            proxy_pass         http://ipgeo;
        }
    }
EOF

#Adding SSL certificate
cat <<EOF > /home/ec2-user/ipgeo-caching/certs/site.crt
<replace with your ssl cert>
EOF

#Adding private key
cat <<EOF > /home/ec2-user/ipgeo-caching/certs/site.key
<replace with your ssl private key>
EOF

#Creating Dockerfile for reverse proxy container image
echo "Building Docker file..."
cat <<EOF > /home/ec2-user/ipgeo-caching/Dockerfile
FROM nginx:alpine

RUN rm /etc/nginx/conf.d/default.conf

COPY ./nginx/nginx.conf /etc/nginx/conf.d/default-nginx.conf

COPY ./certs/site.crt /etc/ssl/certs/site.crt

COPY ./certs/site.key /etc/ssl/certs/site.key
EOF

#Reading ipgeolocation API key and adding it to docker compose file
echo -n "Enter the ipgeolocation (https://ipgeolocation.io/) API key: "
read api_key
echo "Building Docker Compose yaml file..."
cat <<EOF > /home/ec2-user/ipgeo-caching/docker-compose.yml
version: "3"
  
services:
  ipgeo-cache:
    image: redis:latest
    container_name: ipgeo-cache-redis
    networks:
      - ipgeo-grid

  ipgeo-api:
    image: vyshnavlal/ipgeo-apiservice:v1
    container_name: ipgeo-api
    environment:
      - REDIS_HOST=ipgeo-cache
      - APP_PORT=8080
      - API_KEY=$api_key
    ports:
      - "8080:8080" 
    networks:
      - ipgeo-grid
  
  ipgeo-frontend1:
    image: vyshnavlal/ipgeo-frontend:v1
    container_name: ipgeo-frontend1
    environment:
      - API_SERVER=ipgeo-api
      - API_SERVER_PORT=8080
      - API_PATH=/api/v1/
      - APP_PORT=8080
    ports:
      - "8081:8080"
    networks:
      - ipgeo-grid
  
  ipgeo-frontend2:
    image: vyshnavlal/ipgeo-frontend:v1
    container_name: ipgeo-frontend2
    environment:
      - API_SERVER=ipgeo-api
      - API_SERVER_PORT=8080
      - API_PATH=/api/v1/
      - APP_PORT=8080
    ports:
      - "8082:8080"
    networks:
      - ipgeo-grid
  ipgeo-frontend3:
    image: vyshnavlal/ipgeo-frontend:v1
    container_name: ipgeo-frontend3
    environment:
      - API_SERVER=ipgeo-api
      - API_SERVER_PORT=8080
      - API_PATH=/api/v1/
      - APP_PORT=8080
    ports:
      - "8083:8080"
    networks:
      - ipgeo-grid

  reverseproxy:
    build: .
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/logs/:/var/log/nginx/
    networks:
      - ipgeo-grid

networks:
  ipgeo-grid:
EOF

#Starting containers using docker-compose up
echo "Building multi-container application using docker-compose..."
sudo docker-compose up -d

#Listing containers of the project
echo "Containers started successfully... See the status below..."
sudo docker-compose ps

#Giving output URL
echo "Access the site using the URL http://$domain/ip/"

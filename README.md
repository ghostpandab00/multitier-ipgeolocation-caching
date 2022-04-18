## Introduction 
IP-based geolocation may be the ideal answer for you if you're running an e-commerce company or any website that interacting with customer more and want to enhance your conversion rate, reduce bounce rates, or simply make your website more welcoming and memorable.

IP-based geolocation is a way that you can find the location of an internet-connected computing or mobile device. To get started, all you need is your target’s IP address and a geolocation lookup tool. A geolocation lookup tool canvasses public databases to determine the contact and registration information for a particular IP address. With both of these tools in hand, you simply input the IP address into the geolocation lookup tool and you will receive the location of your target.

With an IP address, you can access a wide range of information. To reiterate, however, an IP address isn’t enough. You need to use a geolocation database to obtain this user information. The most basic information provided in most geolocation databases includes the continent, country, state/region, city, and time zone of the electronic device. But along with this, you can discover the internet service provider (“ISP”), approximate longitude and latitude, and sometimes even the relevant organization attached to the device.

#### Common use cases for IP Based Geolocation
There are many different types of use cases for those who want to consider IP-based geolocation to locate online visitors. Here are a few common examples:
 - Showing different offers to users from different locations: IP based geolocation can be used to emphasize a different product to users. For example, users in one location can obtain a physical product (like a course) while other users from a more distant location can be offered a book or online course.
 - Show relevant business opening hours: IP based geolocation can show accurate business hours for a user who is in a particular country or state.
 - Providing a localized feeling: IP based geolocation can display the name of a relevant state or country in a website title in order to provide a localized feeling and attract attention.
 - Translating key messages to the user’s language: A complete translation of a site may be time-consuming, expensive and difficult to maintain. In many cases, using the user’s geolocation to translate key messages like titles and calls to action might do a great job reducing bounce rate and improving conversion rate. You can, for instance, translate key messages like titles and calls to action.
 - Redirect visitors to a page in their language: You can leverage IP based geolocation to deliver content that is more targeted and relevant.
 
There are many IP geolocation database providers. While each database provider gets their IP address information from ARIN (or a different regional Internet Registry), the assignment regularly changes, as some database providers release unwanted IP addresses and others obtain new blocks of IP addresses. Along with this, there are different ways to get the data.

One of the most significant benefits of accessing your data through an API is that the database is constantly updated. In addition, the onus is on the third-party provider to ensure that the data is available to your application. This allows you to focus on your product rather than on building and maintaining the database. There are some downsides, however. API databases may also contain some downtime, which may be inconvenient when you need the data. API databases, while they contain more updated information, may also limit the number of requests that you can make per day.

Here we are using the free plan of ipgeolocation.io and it offers a freemium geolocation API that returns:
- city
- state
- province
- country
- continent
- latitude
- longitude
- region
- timezone
- current time
- organization
- ISP
- local currency
- country flags

This API is free to use up to 1,000 requests/month. Paid plans start at $15/month.

In order to reduce the request count sent to API, we are making use of caching service with the use of Redis.

![cache](https://user-images.githubusercontent.com/65948438/163766081-ed4c6174-e451-47f4-bc50-420ef1bb1065.png)

When a user makes a request, the API service calls Redis to see if the IP is cached, and if it isn't, the API connects the ipgeolocation database to acquire the IP information. Rather than sending the information to the user, the API service caches it in Redis before giving it to the user. So, the following time a user makes a request for the same IP, there is no need for an API request because the information can be retrieved from Redis cache, reducing API queries.

If there are more than one connection to an API at the same time, it can't handle them all at once, thus we're moving to a multi-layer architecture with three front-end services handled by a load balancer. See the final architecture of the app.

![ipgeo](https://user-images.githubusercontent.com/65948438/163767254-6992328a-ff31-4220-97bf-b8bce33a2761.png)

## Pre-requests
- A running Amazon Linux 2 instance
- A domain name which points to the EC2 instance
- SSL for the domain

## Manual method of deploying by using docker compose
We're employing a multi-container architecture, with docker containers running each service. The instances were then started with docker-compose.
```sh
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
      - API_KEY=<api key>
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
```

There are six services we are using:
 - ipgeo-cache: For caching by making use of redis:latest docker image.
 - ipgeo-api: For API Layer
 - ipgeo-frontend1 with port 8081
 - ipgeo-frontend2 with port 8082
 - ipgeo-frontend3 with port 8083
 - reverseproxy: A reverse proxy using Nginx image. All these services are created in a network called 'ipgeo-grid'.

The Flask app is used to build the images for ipgeo-api and ipgeo-frontend(1,2,3). Both are available in my other repository (https://github.com/vyshnavlal/ipgeolocation-flaskapp)

Nginx conf contains the upstream section and proxy pass section, see below:
```sh
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
```
The image for the reverseproxy service is made from a nginx conf and a dockerfile in the project directory.
   
```sh
FROM nginx:alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default-nginx.conf
COPY site.crt /etc/ssl/certs/site.crt
COPY site.key /etc/ssl/private/site.key
```
The SSL certificate and private key needs to be placed at the project directory before running docker-compose up.

### Automate the deployment using a bash script
The above deployment can be automated using a bash script which I've placed below:
```sh
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
<replace the crt file with your own>
EOF

#Adding private key
cat <<EOF > /home/ec2-user/ipgeo-caching/certs/site.key
<replace it with your own private key>
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
```
The result of bash script will be as follows:
```sh
Detected Amazon Linux 2
No Docker version found!... Installing Docker...
Docke-Compose was not found...Installing Docker-Compose
Creating project directory...
Enter the domain name: ipgeo.vyshnavlalp.ml
Building Nginx conf file...
Building Docker file...
Enter the ipgeolocation (https://ipgeolocation.io/) API key: 
Building Docker Compose yaml file...
Building multi-container application using docker-compose...
Creating network "ipgeo-caching_ipgeo-grid" with the default driver
Pulling ipgeo-cache (redis:latest)...
latest: Pulling from library/redis
c229119241af: Pull complete
bed41eb8190a: Pull complete
5e59eaa723f1: Pull complete
fd5ad7669819: Pull complete
566c064eef6e: Pull complete
20c7cfac25de: Pull complete
Digest: sha256:69a3ab2516b560690e37197b71bc61ba245aafe4525ebdece1d8a0bc5669e3e2
Status: Downloaded newer image for redis:latest
Pulling ipgeo-api (vyshnavlal/ipgeo-apiservice:v1)...
v1: Pulling from vyshnavlal/ipgeo-apiservice
486039affc0a: Pull complete
5d0bdab9061e: Pull complete
114369dd54ea: Pull complete
bb272e28936d: Pull complete
516e9ffa026f: Pull complete
4ba553450698: Pull complete
Digest: sha256:f63e9eb94043408518d5674d6509a60a1a85e7e65f01247b9128a3425af498c7
Status: Downloaded newer image for vyshnavlal/ipgeo-apiservice:v1
Pulling ipgeo-frontend1 (vyshnavlal/ipgeo-frontend:v1)...
v1: Pulling from vyshnavlal/ipgeo-frontend
486039affc0a: Already exists
5d0bdab9061e: Already exists
5bc273aca3fa: Pull complete
1d42b997a881: Pull complete
f4ad72a6e0f7: Pull complete
10dc15b5a60e: Pull complete
Digest: sha256:12ff632ac8772c8bda34672cc1f86157e8458c388b591e8fc56654b6c8dd1f2b
Status: Downloaded newer image for vyshnavlal/ipgeo-frontend:v1
Building reverseproxy
Sending build context to Docker daemon   12.8kB
Step 1/5 : FROM nginx:alpine
alpine: Pulling from library/nginx
df9b9388f04a: Pull complete 
5867cba5fcbd: Pull complete 
4b639e65cb3b: Pull complete 
061ed9e2b976: Pull complete 
bc19f3e8eeb1: Pull complete 
4071be97c256: Pull complete 
Digest: sha256:5a0df7fb7c8c03e4158ae9974bfbd6a15da2bdfdeded4fb694367ec812325d31
Status: Downloaded newer image for nginx:alpine
 ---> 51696c87e77e
Step 2/5 : RUN rm /etc/nginx/conf.d/default.conf
 ---> Running in b2255b834e8c
Removing intermediate container b2255b834e8c
 ---> 793126dc4679
Step 3/5 : COPY ./nginx/nginx.conf /etc/nginx/conf.d/default-nginx.conf
 ---> 4af2031410a0
Step 4/5 : COPY ./certs/site.crt /etc/ssl/certs/site.crt
 ---> fb407a175b4c
Step 5/5 : COPY ./certs/site.key /etc/ssl/certs/site.key
 ---> 4914ce423b48
Successfully built 4914ce423b48
Successfully tagged ipgeo-caching_reverseproxy:latest
WARNING: Image for service reverseproxy was built because it did not already exist. To rebuild this image you must use `docker-compose build` or `docker-compose up --build`.
Creating ipgeo-caching_reverseproxy_1 ... done
Creating ipgeo-frontend3              ... done
Creating ipgeo-frontend1              ... done
Creating ipgeo-frontend2              ... done
Creating ipgeo-cache-redis            ... done
Creating ipgeo-api                    ... done
Containers started successfully... See the status below...
            Name                          Command               State                                   Ports                                 
----------------------------------------------------------------------------------------------------------------------------------------------
ipgeo-api                      python3 app.py                   Up      0.0.0.0:8080->8080/tcp,:::8080->8080/tcp                              
ipgeo-cache-redis              docker-entrypoint.sh redis ...   Up      6379/tcp                                                              
ipgeo-caching_reverseproxy_1   /docker-entrypoint.sh ngin ...   Up      0.0.0.0:443->443/tcp,:::443->443/tcp, 0.0.0.0:80->80/tcp,:::80->80/tcp
ipgeo-frontend1                python3 app.py                   Up      0.0.0.0:8081->8080/tcp,:::8081->8080/tcp                              
ipgeo-frontend2                python3 app.py                   Up      0.0.0.0:8082->8080/tcp,:::8082->8080/tcp                              
ipgeo-frontend3                python3 app.py                   Up      0.0.0.0:8083->8080/tcp,:::8083->8080/tcp                              
Access the site using the URL http://ipgeo.vyshnavlalp.ml/ip/
```
We can check the IP info by using the URL http://ipgeo.vyshnavlalp.ml/ip/ followed by the required IP like http://ipgeo.vyshnavlalp.ml/ip/8.8.8.8

![2](https://user-images.githubusercontent.com/65948438/163780378-3abfe89c-fe33-4230-b345-8c598ed25e39.png)

![3](https://user-images.githubusercontent.com/65948438/163780403-03e784e2-7ede-46ca-903a-e70a2bc5917a.png)

You can see that when I first request an IP, the cached status is false, but when I request the same IP again, the cached status changes to True, indicating that when we make requests for the same IP, the result is received from the cache service rather than an API request, reducing API queries. Because we are utilising a multi-container system, you can also observe that the results are fetched from different containers by looking at the container hostname or IP.

That's all

If you learned something from my blog, please remember to share it ⭐ and if you REALLY enjoyed it, please follow me! Thanks for reading this. 



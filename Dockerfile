FROM nginx:alpine

RUN rm /etc/nginx/conf.d/default.conf

COPY ./nginx/nginx.conf /etc/nginx/conf.d/default-nginx.conf

COPY ./certs/site.crt /etc/ssl/certs/site.crt

COPY ./certs/site.key /etc/ssl/certs/site.key

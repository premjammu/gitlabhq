FROM httpd:2.4.65-alpine3.22

COPY ./ /usr/local/apache2/htdocs/

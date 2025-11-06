FROM alpine:3.18
RUN apk add --no-cache bash curl
COPY app.sh /app/app.sh
RUN chmod +x /app/app.sh
CMD ["/bin/sh", "/app/app.sh"]

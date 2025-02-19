FROM alpine:3.18

RUN apk add --no-cache bash jq

COPY shell/json-env.sh /usr/local/bin/json-env

ENTRYPOINT ["json-env"]

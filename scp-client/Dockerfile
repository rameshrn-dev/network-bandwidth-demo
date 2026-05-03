FROM alpine:3.19
RUN apk add --no-cache openssh-client sshpass bash
COPY transfer.sh /transfer.sh
RUN chmod +x /transfer.sh
CMD ["tail", "-f", "/dev/null"]

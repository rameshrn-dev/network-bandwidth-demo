FROM alpine:3.19
RUN apk add --no-cache curl bc bash
COPY measure.sh /measure.sh
RUN chmod +x /measure.sh
# Default route via router so all traffic passes through the bandwidth cap
RUN echo "#!/bin/sh" > /etc/network/if-up.d/default-route && \
    echo "ip route add default via 172.20.0.1 || true" >> /etc/network/if-up.d/default-route && \
    chmod +x /etc/network/if-up.d/default-route
CMD ["tail", "-f", "/dev/null"]

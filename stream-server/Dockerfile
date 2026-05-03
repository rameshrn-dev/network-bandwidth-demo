FROM nginx:alpine
# Generate a 500 MB random binary file used as the "video stream" source.
# /dev/urandom ensures nginx can't cache or compress it, so bandwidth is
# actually consumed on every request.
RUN dd if=/dev/urandom of=/usr/share/nginx/html/stream.bin bs=1M count=500 2>/dev/null
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80

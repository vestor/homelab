FROM ubuntu:jammy
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
apt-get install -y --no-install-recommends wget ca-certificates && \
rm -rf /var/lib/apt/lists/*
RUN wget -qP /tmp https://github.com/awawa-dev/HyperHDR/releases/download/v21.0.0.0/HyperHDR-21.0.0.0.jammy-x86_64.deb && \
apt-get update && \
apt-get install -y --no-install-recommends /tmp/HyperHDR-21.0.0.0.jammy-x86_64.deb && \
rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*
RUN mkdir -p /config && chmod -R 777 /config
EXPOSE 8090 8092 19400 19444 19445
ENTRYPOINT ["hyperhdr", "-v", "-u=/config"]
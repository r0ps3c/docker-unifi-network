FROM ubuntu AS builder
ENV DEBIAN_FRONTEND=noninteractive
RUN \
	apt update && \
	apt -y install equivs
COPY mongodb-server.equivs /tmp
RUN \
	cd /tmp && \
	equivs-build mongodb-server.equivs

FROM ubuntu
LABEL org.opencontainers.image.title="UniFi Network Application"
LABEL org.opencontainers.image.description="Ubiquiti UniFi Network Application"
LABEL org.opencontainers.image.vendor="Custom Build"
LABEL org.opencontainers.image.source="https://github.com/r0ps3c/docker-unifi-network"
COPY --from=builder /tmp/mongodb-server*.deb /tmp/
RUN \
	apt update && \
	apt -y install ca-certificates apt-transport-https wget gnupg && \
	dpkg -i /tmp/mongodb-server*deb && \
	echo 'deb https://www.ui.com/downloads/unifi/debian stable ubiquiti' > /etc/apt/sources.list.d/100-ubnt-unifi.list && \
	wget -qO /etc/apt/trusted.gpg.d/unifi-repo.gpg https://dl.ui.com/unifi/unifi-repo.gpg && \
	apt update && \
	useradd --shell /bin/false --uid 5000 --home /var/lib/unifi --no-create-home unifi && \
	apt install -yy unifi && \
	apt -y --purge autoremove && \
        apt -y clean && \
        rm -rf /var/lib/apt/lists/* /tmp/* && \
	mkdir -p /logs /usr/lib/unifi/run /usr/lib/unifi/data && \
	chown -R unifi:unifi /logs /usr/lib/unifi/run /usr/lib/unifi/data

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER unifi
EXPOSE 8080 8443
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

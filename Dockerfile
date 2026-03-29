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
ARG UNIFI_VERSION
RUN \
	apt update && \
	apt -y install ca-certificates curl && \
	dpkg -i /tmp/mongodb-server*.deb && \
	if [ -z "${UNIFI_VERSION}" ]; then \
		UNIFI_VERSION=$(curl -sf \
			'https://fw-update.ubnt.com/api/firmware-latest?filter=eq~~product~~unifi-controller&filter=eq~~platform~~unix&filter=eq~~channel~~release' \
			| grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//' | cut -d'+' -f1); \
	fi && \
	curl -fL -o /tmp/unifi.deb "https://dl.ui.com/unifi/${UNIFI_VERSION}/unifi_sysvinit_all.deb" && \
	useradd --shell /bin/false --uid 5000 --home /var/lib/unifi --no-create-home unifi && \
	apt install -y /tmp/unifi.deb && \
	apt -y --purge autoremove && \
	apt -y clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* && \
	mkdir -p /logs /usr/lib/unifi/run /usr/lib/unifi/data && \
	chown -R unifi:unifi /logs /usr/lib/unifi/run /usr/lib/unifi/data

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER unifi
EXPOSE 8080 8443
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

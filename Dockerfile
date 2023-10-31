FROM ubuntu as builder
ENV DEBIAN_FRONTEND noninteractive
RUN \
	apt update && \
	apt -y install equivs
COPY mongodb-server.equivs /tmp
RUN \
	cd /tmp && \
	equivs-build mongodb-server.equivs

FROM ubuntu
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
	mkdir -p /logs /usr/lib/unifi/run && \
	chown -R unifi:unifi /logs /usr/lib/unifi/run

USER unifi
EXPOSE 8080 8443
# taken from /usr/lib/unifi/bin/unifi.init
ENTRYPOINT ["/usr/bin/java", "-Dfile.encoding=UTF-8", "-Djava.awt.headless=true", "-Dapple.awt.UIElement=true", "-Dunifi.core.enabled=false","-Xmx1024M","-XX:+UseParallelGC", "-XX:+ExitOnOutOfMemoryError", "-XX:+CrashOnOutOfMemoryError","-XX:ErrorFile=/var/run/unifi/hs_err_pid%p.log","-Dunifi.datadir=/usr/lib/unifi/data/","-Dunifi.logdir=/logs","-Dunifi.rundir=/var/run/unifi", "--add-opens","java.base/java.lang=ALL-UNNAMED", "--add-opens","java.base/java.time=ALL-UNNAMED", "--add-opens","java.base/sun.security.util=ALL-UNNAMED", "--add-opens","java.base/java.io=ALL-UNNAMED", "--add-opens","java.rmi/sun.rmi.transport=ALL-UNNAMED","-Dlog4j2.formatMsgNoLookups=true","-jar","/usr/lib/unifi/lib/ace.jar","start"]

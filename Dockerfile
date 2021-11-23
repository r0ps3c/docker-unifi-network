FROM ubuntu
ENV DEBIAN_FRONTEND noninteractive
ARG UNIFI_VER="6.5.53"
RUN \
	apt update && \
	apt -y install ca-certificates apt-transport-https wget gnupg openjdk-8-jre-headless && \
	echo 'deb https://www.ui.com/downloads/unifi/debian stable ubiquiti' > /etc/apt/sources.list.d/100-ubnt-unifi.list && \
	wget -qO- https://dl.ui.com/unifi/unifi-repo.gpg | apt-key add && \
	apt update && \
	apt install -yy unifi=$UNIFI_VER\* && \
	apt -y dist-upgrade && \
	apt-get clean && \
	wget -qO /usr/share/java/activation.jar https://repo1.maven.org/maven2/com/sun/activation/jakarta.activation/1.2.2/jakarta.activation-1.2.2.jar && \
	mkdir -p /logs /usr/lib/unifi/run && \
	chown -R unifi:unifi /logs /usr/lib/unifi/run

USER unifi
EXPOSE 8080 8443
ENTRYPOINT ["/usr/bin/java","-cp","/usr/share/java/commons-daemon.jar:/usr/lib/unifi/lib/ace.jar:/usr/share/java/activation.jar","-Dunifi.datadir=/var/lib/unifi","-Dunifi.logdir=/var/log/unifi","-Dunifi.rundir=/var/run/unifi","-Xmx1024M","-Djava.awt.headless=true","-Dfile.encoding=UTF-8","-Xmx1024M","com.ubnt.ace.Launcher","start"]
#ENTRYPOINT ["/usr/bin/jsvc","-home","/usr/lib/jvm/java-8-openjdk-amd64","-cp","/usr/share/java/commons-daemon.jar:/usr/lib/unifi/lib/ace.jar","-pidfile","/var/run/unifi/unifi.pid","-procname","unifi","-outfile","SYSLOG","-errfile","SYSLOG","-Xmx1024M","-Djava.awt.headless=true","-Dfile.encoding=UTF-8","-nodetach","com.ubnt.ace.Launcher"]

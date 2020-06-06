FROM ubuntu
ENV DEBIAN_FRONTEND noninteractive
RUN \
	apt update && \
	apt -yy dist-upgrade && \
	apt install -yy gnupg wget openjdk-8-jre-headless jsvc && \
	echo "deb http://www.ubnt.com/downloads/unifi/debian stable ubiquiti" >  /etc/apt/sources.list.d/100-ubnt.list && \
	wget -qO- https://dl.ubnt.com/unifi/unifi-repo.gpg | apt-key add && \
	echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org.list && \
	wget -qO- https://www.mongodb.org/static/pgp/server-3.4.asc | apt-key add && \
	apt update && \
	apt install -yy mongodb-org unifi && \
	apt-get clean && \
	mkdir -p /logs /usr/lib/unifi/run && \
	chown -R unifi:unifi /logs /usr/lib/unifi/run

USER unifi
EXPOSE 8080 8443
ENTRYPOINT ["/usr/bin/java","-cp","/usr/share/java/commons-daemon.jar:/usr/lib/unifi/lib/ace.jar","-Dunifi.datadir=/var/lib/unifi","-Dunifi.logdir=/var/log/unifi","-Dunifi.rundir=/var/run/unifi","-Xmx1024M","-Djava.awt.headless=true","-Dfile.encoding=UTF-8","-Xmx1024M","com.ubnt.ace.Launcher","start"]
#ENTRYPOINT ["/usr/bin/jsvc","-home","/usr/lib/jvm/java-8-openjdk-amd64","-cp","/usr/share/java/commons-daemon.jar:/usr/lib/unifi/lib/ace.jar","-pidfile","/var/run/unifi/unifi.pid","-procname","unifi","-outfile","SYSLOG","-errfile","SYSLOG","-Xmx1024M","-Djava.awt.headless=true","-Dfile.encoding=UTF-8","-nodetach","com.ubnt.ace.Launcher"]

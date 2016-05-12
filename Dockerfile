FROM exira/base:3.3.3

MAINTAINER exira.com <info@exira.com>

ARG CONTAINER_UID=1001
ARG CONTAINER_GID=1001

ENV INFLUXDB_VERSION=0.13.0-1 \
    INFLUXDB_FILE=influxdb-0.13.0_linux_amd64 \
    GLIBC_VERSION=2.23-r1 \
    INFLUXDB_HOME=/data \
    CONTAINER_USER=influxdb \
    CONTAINER_GROUP=influxdb \
    PRE_CREATE_DB=**None**

ENV GLIBC_FILE=glibc-${GLIBC_VERSION}.apk

RUN \
    # Install build and runtime packages
    build_pkgs="wget openssl ca-certificates" && \
    runtime_pkgs="bash curl" && \
    apk update && \
    apk upgrade && \
    apk --update --no-cache add ${build_pkgs} ${runtime_pkgs} && \

    # add influxdb user
    mkdir -p /home/${CONTAINER_USER} && \
    addgroup -g $CONTAINER_GID -S ${CONTAINER_GROUP} && \
    adduser -u $CONTAINER_UID  -S -D -G ${CONTAINER_GROUP} -h /home/${CONTAINER_USER} -s /bin/sh ${CONTAINER_USER} && \
    chown -R ${CONTAINER_USER}:${CONTAINER_GROUP} /home/${CONTAINER_USER} && \

    # install glibc
    wget -O /etc/apk/keys/andyshinn.rsa.pub https://raw.githubusercontent.com/andyshinn/alpine-pkg-glibc/master/andyshinn.rsa.pub && \
    wget -O /tmp/${GLIBC_FILE} https://github.com/andyshinn/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/${GLIBC_FILE} && \
    apk add /tmp/${GLIBC_FILE} && \

    # install influxdb
    wget -O /tmp/${INFLUXDB_FILE}.tar.gz https://dl.influxdata.com/influxdb/releases/${INFLUXDB_FILE}.tar.gz && \
    tar xvfz /tmp/${INFLUXDB_FILE}.tar.gz -C /tmp && \
    cp /tmp/influxdb-${INFLUXDB_VERSION}/usr/bin/* /usr/bin && \
    cp -r /tmp/influxdb-${INFLUXDB_VERSION}/etc/influxdb /etc && \
    echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
    mkdir -p ${INFLUXDB_HOME} && \
    chown -R ${CONTAINER_USER}:${CONTAINER_GROUP} ${INFLUXDB_HOME} && \

    # remove dev dependencies
    apk del ${build_pkgs} && \

    # other clean up
    rm -rf /var/cache/apk/* && \
    rm -rf /tmp/* && \
    rm -rf /var/log/*

ADD config.toml /etc/influxdb.toml
ADD types.db /usr/share/collectd/types.db

ADD run.sh /run.sh
RUN chmod +x /run.sh

# Get decent Linux line endings
RUN dos2unix /etc/influxdb.toml && \
    dos2unix /usr/share/collectd/types.db && \
    dos2unix /run.sh

# Admin server WebUI
EXPOSE 8083

# HTTP API
EXPOSE 8086

# Raft port (for clustering, don't expose publicly!)
#EXPOSE 8090

# Protobuf port (for clustering, don't expose publicly!)
#EXPOSE 8099

VOLUME ["/data"]

WORKDIR ${INFLUXDB_HOME}

CMD ["/run.sh"]

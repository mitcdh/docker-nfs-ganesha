FROM ubuntu:xenial
MAINTAINER Mitchell Hewes <me@mitcdh.com>

# install prerequisites
RUN DEBIAN_FRONTEND=noninteractive \
 && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EA914D611053D07BD332E18010353E8834DC57CA \
 && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F7C73FCC930AC9F83B387A5613E01B7B3FE869A9 \
 && echo "deb http://ppa.launchpad.net/nfs-ganesha/nfs-ganesha-2.8/ubuntu xenial main" > /etc/apt/sources.list.d/nfs-ganesha-2.5.list \
 && echo "deb http://ppa.launchpad.net/nfs-ganesha/libntirpc-1.8/ubuntu xenial main" > /etc/apt/sources.list.d/libntirpc-1.5.list \
 && echo "deb http://ppa.launchpad.net/gluster/glusterfs-6/ubuntu xenial main" > /etc/apt/sources.list.d/glusterfs-3.11.list \
 && apt-get update \
 && apt-get install -y netbase nfs-common dbus nfs-ganesha nfs-ganesha-vfs glusterfs-common \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
 && mkdir -p /run/rpcbind /export /var/run/dbus \
 && touch /run/rpcbind/rpcbind.xdr /run/rpcbind/portmap.xdr \
 && chmod 755 /run/rpcbind/* \
 && chown messagebus:messagebus /var/run/dbus

# Add startup script
COPY start.sh /

# NFS ports and portmapper
EXPOSE 2049 38465-38467 662 111/udp 111

# Start Ganesha NFS daemon by default
CMD ["/start.sh"]

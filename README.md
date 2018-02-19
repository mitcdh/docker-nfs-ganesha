# NFS Ganesha
A user mode nfs server implemented in a container with some baked-in configuration specific to the OSiRIS project (http://www.osris.org).  Designed for serving CephFS and RGW exports with KRB5 auth and idmap config using UMICH_LDAP backend.

Within the scope of this container's intended use many settings are set with environment variables that use defaults reasonable for the OSiRIS project but can be over-ridden as needed.  It is not meant to be suitable for serving configurations that do not use Ceph + NFVSv4 + KRB5 + Idmap/LDAP but it could be configured to your specific environment within those constraints.   

This container includes a CA cert specific to OSiRIS referenced for ldaps connections.  Depending on how your ldap server certificate is signed you may need to modify this container to include your CA cert.  Well-known public CA should work without modification.

## KRB5 config

You must create principals in your Kerberos domain for both the server and the client mounting the NFS filesystem:

```
kadmin:  addprinc -randkey host/server.example.org
kadmin:  addprinc -randkey nfs/server.example.org
kadmin:  addprinc -randkey nfs/client.example.org
kadmin:  addprinc -randkey host/client.example.org
```

You must then put principals in keytabs for the client and server (different keytab for each).  Ensure this file is kept secure and private, only readable by root on each system.

```
kadmin:  ktadd -k server.keytab host/server.example.org
kadmin:  ktadd -k server.keytab nfs/server.example.org
```

Copy server.keytab to /etc/krb5.keytab on server.example.org.  Repeat this process creating a different keytab for client.example.org.  

## LDAP Config

KRB5 principal lookup and LDAP ID mapping requires appropriate attributes be set on LDAP user objects and objects specified for NFSv4 remote names.  More information:
http://www.citi.umich.edu/projects/nfsv4/crossrealm/libnfsidmap_config.html

OSiRIS includes an adapted LDAP schema for the 389 Directory Server in our puppet module.
https://github.com/MI-OSiRIS/puppet-ds389

The idmapd.conf included in this image uses default attributes matching that schema.  Below is an example for a user entry that would match with a remote user having kerberos ticket for user@EXAMPLE.EDU whose client is using NFSv4 domain example.edu.  It is not required to map local users/groups to your users and groups for determining access capabilities.  NFS client user capabilities will be determined by the server according to GSS identity mapping to a uid/gid combo resolvable to file ownership/capabilities on the server.  However if a mapping does not exist the client will see only 'nobody' as owner of files and not be able to use utils like chgrp, etc.  

The NFSv4 domain is set by Domain setting in /etc/idmapd.conf on client and defaults to domain component of hostname if not set.  

Prerequisite:  You have a user id 2046 which this container can resolve and determine group memberships for via sssd or passwd/group files (provided with -v option to docker run)

LDAP Example

GSS Identity + Remote User
```
dn: cn=nfs-user,ou=NFSPeople,dc=example,dc=edu
objectClass: NFSv4RemotePerson
objectClass: top
uidNumber: 2046
gidNumber: 2046
NFSv4Name: user_local@example.edu
GSSAuthName: user@EXAMPLE.EDU
GSSAuthName: user2@EXAMPLE2.EDU
cn: nfs-user
```

To define additional remote user mappings define more objects with uid/gid known to the server/container, GSSAuthName matching remote krb5 principal, and NFSv4Name matching localuser@nfsv4domain.

Remote Group Mapping:

```
dn: cn=nfs-group,ou=NFSGroups,dc=example,dc=edu
objectClass: NFSv4RemoteGroup
objectClass: top
gidNumber: 2046
NFSv4Name: group-local@example.edu
cn: nfs-group
```

To define additional remote group mappings define more objects with gidNumber known to server/container and NFSv4Name matching localuser@nfsv4domain.  

In our example we use a simple object with just attributes needed for NFSv4 and uid/gid.  The uid and gid defined here match posixAccount and posixGroup objects elsewhere in LDAP referenced by SSSD configuration passed to the container (or they could be resolvable by local passwd/group files as well).  You could also set objectClass NFSv4RemotePerson and posixAccount on a single object and combine them but you can only set one NFSv4Name attribute so will need multiple NFSv4RemotePerson objects for each remote user@domain requiring mapping and they'll have to be in the same OU as your posixAccount objects.  

### Versions
* ganesha: 2.5.5 from http://download.ceph.com/nfs-ganesha/deb-V2.5-stable/luminous/

For more info on ganesha options please see:  https://github.com/nfs-ganesha/nfs-ganesha/blob/master/src/config_samples/config.txt

Environment variables are shown below with defaults.

### Ganesha Environment Variables

* `GANESHA_LOGFILE`: "/dev/stdout"
* `GANESHA_CONFIGFILE`: "/etc/ganesha/ganesha.conf"
* `GANESHA_OPTIONS`: "-N NIV_EVENT" 
* `GANESHA_EPOCH`: ""
* `GANESHA_EXPORT_ID`: "2046"
* `GANESHA_EXPORT`: "/"
* `GANESHA_ACCESS`: "*"
* `GANESHA_ROOT_ACCESS`: "*"
* `GANESHA_NFS_PROTOCOLS`: "4"
* `GANESHA_TRANSPORTS`: "TCP"
* `GANESHA_SECTYPE`: "krb5"
* `GANESHA_KRB5_PRINCIPAL`: "nfs"
* `GANESHA_CLIENT_LIST`: "*"

### Ceph Environment Variables

You must provide a client key with capabilities to access your filesystem and underlying data pools.  For example, you could create such a key on your cluster with this command:
 ` ceph auth get-or-create client.ganesha mds 'allow r, allow rw path=/restrict/path' mgr 'allow r' mon 'allow r' osd 'allow rw pool=cephfs_data'

The path restriction is not required if you wish to serve your entire FS.  In that case use 'allow rw' by itself to allow rw to any fs path.    

* `CEPH_CLIENT_ID`: "ganesha"
* `CEPH_CLIENT_KEY`: "None"
* `CEPH_FS_PATH`: "/"

### NFS IDMAP Environment Variables
* `IDMAP_DOMAIN`: "osris.org"
* `IDMAP_LDAP_SERVER`: "ldap"
* `IDMAP_LDAP_SSL`: "true"
* `IDMAP_LDAP_SSL_CA`: "/etc/ssl/certs/ca-certificates.crt"
* `IDMAP_LDAP_BASE`: dc=osris,dc=org
* `IDMAP_LDAP_PEOPLE_BASE`: ou=NFSPeople,${IDMAP_LDAP_BASE}
* `IDMAP_LDAP_GROUP_BASE`: ou=NFSPeople,${IDMAP_LDAP_BASE}

* `CEPH_MON`: "mon"

CEPH_MON can be a comma separated list of multiple monitor hosts.  

For more details on environment placement in config files please look at start.sh in this repository.  

### Usage
```bash
 docker run -P -p 2049:2049 --name ceph-nfs \ 
 -e 'CEPH_CLIENT_ID=ganesha' \
 -e 'CEPH_CLIENT_KEY=AbC123==' \
 -v /etc/krb5.conf:/etc/krb5.conf:ro \
 -v /etc/krb5.keytab:/etc/krb5.keytab:ro \
 -v/etc/sssd/sssd.conf:/etc/sssd/sssd.conf:ro \
 --hostname=nfs.example.edu --privileged miosiris/nfs-ganesha-ceph
```

### Credits
* Forked from: [mitcdh/docker-nfs-ganesha](https://github.com/mitcdh/docker-nfs-ganesha)
* Reference:  [ehough/docker-nfs-server](https://github.com/ehough/docker-nfs-server)

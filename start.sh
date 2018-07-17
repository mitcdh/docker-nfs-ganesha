#!/bin/bash
set -e

# Options for starting Ganesha
: ${GANESHA_LOGFILE:="/dev/stdout"}
: ${GANESHA_CONFIGFILE:="/etc/ganesha/ganesha.conf"}
: ${GANESHA_OPTIONS:="-N NIV_EVENT"} # NIV_DEBUG
: ${GANESHA_EXPORT_ID:="2046"}
: ${GANESHA_EXPORT:="/cephfs"}
: ${GANESHA_CLIENT_LIST:="*"}
: ${GANESHA_NFS_PROTOCOLS:="4"}
: ${GANESHA_TRANSPORTS:="TCP"}
: ${GANESHA_SECTYPE:="krb5"}
: ${GANESHA_KRB5_PRINCIPAL="nfs"}

# config requirements for Ceph
: ${CEPH_CLIENT_ID:="ganesha"}
: ${CEPH_CLIENT_KEY:="None"}
: ${CEPH_FS_PATH:="/"}

# nfs config requirements
: ${IDMAP_DOMAIN:="$(hostname -d)"}
: ${IDMAP_LDAP_SERVER:="ldap.example.org"}
: ${IDMAP_LDAP_SSL:="true"}
: ${IDMAP_LDAP_SSL_CA:="/etc/ssl/certs/ca-certificates.crt"}
: ${IDMAP_LDAP_BASE="dc=example,dc=org"}
: ${IDMAP_LDAP_PEOPLE_BASE="ou=NFSPeople,${IDMAP_LDAP_BASE}"}
: ${IDMAP_LDAP_GROUP_BASE="ou=NFSGroups,${IDMAP_LDAP_BASE}"}

: ${CEPH_MON:="mon"}

function bootstrap_ganesha_config {
    echo "Bootstrapping Ganesha NFS config"
  cat <<END >${GANESHA_CONFIGFILE}

NFSV4 {
    Allow_Numeric_Owners = false;
 }

NFS_KRB5
{
   PrincipalName = ${GANESHA_KRB5_PRINCIPAL};
   KeytabPath = /etc/krb5.keytab;
   Active_krb5 = YES;
}

EXPORT
{
        # Export Id (mandatory, each EXPORT must have a unique Export_Id)
        Export_Id = ${GANESHA_EXPORT_ID};

        # Exported path (mandatory)
        Path = ${CEPH_FS_PATH};

        # Pseudo Path (for NFS v4)
        Pseudo = ${GANESHA_EXPORT};

        # Access control options
        Access_Type = NONE;
        Squash = Root_Squash;

        # NFS protocol options
        Transports = "${GANESHA_TRANSPORTS}";
        Protocols = "${GANESHA_NFS_PROTOCOLS}";

        SecType = "${GANESHA_SECTYPE}";
        Manage_Gids = true;

        CLIENT {
            Clients = ${GANESHA_CLIENT_LIST};
            Access_Type = RW;
        }

        # Exporting FSAL
        FSAL {
            Name = CEPH;
            User_Id = "${CEPH_CLIENT_ID}";
            Secret_Access_Key = "${CEPH_CLIENT_KEY}";
        }
}

LOG {
        Default_Log_Level = WARN;
        Components {
                # ALL = DEBUG;
                # SESSIONS = INFO;
         }
}

END

}

function bootstrap_ca_cert {
    echo "Bootstrapping CA cert"
    cat<<END >> /etc/ssl/certs/ca-certificates.crt
-----BEGIN CERTIFICATE-----
MIIFhTCCA22gAwIBAgIBATANBgkqhkiG9w0BAQsFADApMScwJQYDVQQDDB5QdXBw
ZXQgQ0E6IHVtLXB1cHBldC5vc3Jpcy5vcmcwHhcNMTYwNDEyMTU1OTU5WhcNMzYw
NDA4MTU1OTU5WjApMScwJQYDVQQDDB5QdXBwZXQgQ0E6IHVtLXB1cHBldC5vc3Jp
cy5vcmcwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDWdrCSXje9FwsU
29UQJkMFFkdTXFy0StyaE7RoQgAW5tD4f7BqqY50QRjV6qTmqLZrxVeyDtoXvHZp
nIcSEiKX+P9VQ8k1VbCyAkg7tcneW0fECVev0ieEAVezpU9DVofVZ8b+grwHxHVd
iuuzVApWaUezpoFjMhxPniGwehrJXkuJhzqmjxKFZyN/JIHZ9USal4IMqfK6dd/1
Xl7xKl4t1nBKX3wQOdEkKR9WTAqip1SETV0gssxPQghoK28NenDGwxgVgmyJNMDr
MAjwvsEOefUObljS6Nq8WefdGL/SpN6pUhGWvP1eu7bSO7LgNHfUslPae3BjGFB5
Yx0FV6pjNRXZYJEADCadm1ZwHFvtK9aw6IVb/qwqKfqrkZfmvC15HRpS8bmGuQaW
CsMi8ItQqft92LLsP0MEmFVjRq6T2W6DJgv4tog8iHT31VVYvcBOrESOMvuIgN8x
gfRd9IR6qvcaHqFCmwb7rcw6kjnXlCA/QHnx24jqwgUUhOZjujDfx27Nn18nn2OU
myVgcC0cNfadeX802yEMFEDoyEz73VNfEGPX1ZxAnTJnzJGO7ThP/GoYcV53es+S
s4EAjFDQn2TnCP2xTW9kSST0j2f/5eKe2DidQgPaLsfXWhEToC1QYbtCfInmtnp2
v+A+eji9pnwQraVnSaZ7NVi8bNRguwIDAQABo4G3MIG0MDUGCWCGSAGG+EIBDQQo
UHVwcGV0IFJ1YnkvT3BlblNTTCBJbnRlcm5hbCBDZXJ0aWZpY2F0ZTAOBgNVHQ8B
Af8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUdzAqUUVU4uLu8RoP
u+M1qNJAgZowOwYDVR0jBDQwMqEtpCswKTEnMCUGA1UEAwweUHVwcGV0IENBOiB1
bS1wdXBwZXQub3NyaXMub3JnggEBMA0GCSqGSIb3DQEBCwUAA4ICAQCwsDWWofkx
HM2s0UDwb6kMyplk9PZUnzujR2Tm7cTObW6RrTJcOgh1VflpkUvdZCNDZDXu6sS+
bZa+PPnp/rCzEJ92n8wcEAyP9alXue6TiyOo4L7oyY0RvXax/udbjWAwh5CCswly
t36fkp88awvf2oJH22jifFj/n1IOKMjQuDottMnmsTyrO/WeHWpS/Yosus+pLmfb
BdBH6FE7zXniam2UHSfpByC4pHVp2bDFX/TR6ZgAySUyYpBBSe6hcHdsn50WTwD2
JREe/WI4hkNRDLmbMxkLNsqIQc4JknnmQ2zCd/4XbgRSR0q1MLxC5oHhOv7dgM2s
SN1DkyIPq76ONB+HyHxAoQTGbiXuBrzIz0JxKDXuh2fQ6VRGWWPrxTSM1vVPtNKE
KEjviwpbnM1UqoH7q/qXzOr0CNlIEtHoZfCLYbdML5J3tEtvydWW4pyMIkTVV7B8
d2ywZSk0y2iyxC3EqmAYe7RVJ2N7C7dSzgYv2b+1LgdLzCxaoWRoaSw2hW5XIwUu
kLmL3Ua6KXLnb3npmeGO9RFHTglRFuI5p+rvaEW5Cep7CrafzUBbVHzN1WV9F3NO
JLZUKCc45cZiTf/EZd7B8Zbt45gcT6/Hfq79Hs3NAJ2RiHwSGZwwPWcGcum7XCM5
2+gLDOHjdNVMIw0Zq79Q1n358ky4y+ku5g==
-----END CERTIFICATE-----
END


}

function bootstrap_idmap_config {
    echo "Bootstrapping idmap config"
    cat<<END > /etc/idmapd.conf
[General]
Domain = ${IDMAP_DOMAIN}

[Translation]
Method = umich_ldap, nsswitch

[UMICH_SCHEMA]
LDAP_server = ${IDMAP_LDAP_SERVER}
LDAP_base = ${IDMAP_LDAP_BASE}
LDAP_canonicalize_name = false
LDAP_people_base = ${IDMAP_LDAP_PEOPLE_BASE}
LDAP_group_base = ${IDMAP_LDAP_GROUP_BASE}
LDAP_use_ssl = ${IDMAP_LDAP_SSL}
LDAP_ca_cert = ${IDMAP_LDAP_SSL_CA}

END

}

function bootstrap_ceph_config {
    echo "Boostrapping Ceph config"
    mkdir /etc/ceph
    cat <<END >/etc/ceph/ceph.conf
[global]
mon_host = ${CEPH_MON}

END

}

function init_services {
    echo "Starting rpc services"
    rpcbind || return 0
    rpc.statd -L || return 0
    echo "Starting sssd"
    sssd -D || return 0

    # not needed with ganesha
    # rpc.gssd || return 0
    # rpc.idmapd || return 0
    sleep 1
}

function init_dbus {
    echo "Starting dbus"
    rm -f /var/run/dbus/system_bus_socket
    rm -f /var/run/dbus/pid
    dbus-uuidgen --ensure
    dbus-daemon --system --fork
    sleep 1
}

function startup_script {
    if [ -f "${STARTUP_SCRIPT}" ]; then
    /bin/sh ${STARTUP_SCRIPT}
    fi
}

bootstrap_ganesha_config
bootstrap_ca_cert
bootstrap_idmap_config
bootstrap_ceph_config
startup_script

if [ ! -f /etc/krb5.keytab ] && [[ $GANESHA_SECTYPE == *"krb5"* ]]; then
    echo "/etc/krb5.keytab not provided"
    exit 1
fi

if [ ! -f /etc/krb5.conf ] && [[ $GANESHA_SECTYPE == *"krb5"* ]]; then
    echo "/etc/krb5.conf not provided"
    exit 1
fi

init_services
init_dbus

echo "Starting Ganesha NFS"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib
exec /usr/bin/ganesha.nfsd -F -L ${GANESHA_LOGFILE} -f ${GANESHA_CONFIGFILE} ${GANESHA_OPTIONS}

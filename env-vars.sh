########################################################################################################
########################################################################################################

# env-vars.sh

########################################################################################################
########################################################################################################

# directory where artifacts of these scripts will be saved
export WORK_DIR=$HOME/setup-kubernetes

# how to configure git
export GIT_CONFIG_USERNAME=
export GIT_CONFIG_EMAIL=

export CLUSTER_NAME=my-cluster

# all of the dns names created will be children of this domain
export PRI_DOMAIN=example.com
export KUBE_ADMIN_USER=me@example.com

# name of lvm volume group in which to create persistent volumes
export PERSISTENT_VOLUME_GROUP=ubuntu-vg

# an ip address that can be wellknown to the dns server, for reading the zone
# data set by the external-dns systme
# The IP address to assign to the etcd client service which fronts the etcd
# cluster which in turn supports the external-dns container in the
# intranet-dns namespace.
export INTRANET_DNS_ETCD_FIXED_IP="10.96.1.1"

# If your lan isn't 10.0.0.0/16, and/or your host isn't 10.0.0.10, you'll need
# to modify these.

# The kubernetes master node IP address in the lan on which host runs
export ADVERTISE_ADDR="10.0.0.10"

# IP to be assigned by metallb for the nginx-controller service serving
# public internet sites. It will serve sites running in the PUBLIC_IP_RANGE
# range.
export LB_IP="10.0.1.1"
# Same, but for private (intranet) sites. It will serve sites running in the
# PRIVATE_IP_RANGE range.
export LB_INTRANET_IP="10.0.4.1"
# The script configures an instance of coredns (separate from those serving
# kubernetes itself). This is used for serving as an intranet name server (i.e.
# covering the zone intranet.$PRI_DOMAIN).
# This is the IP address that will be assigned to that dns server.
export INTRANET_DNS_IP="10.0.1.2"
# IP range for metallb to assign to ingresses which should be exposed separately
# from the nginx-ingress.
export PUBLIC_IP_RANGE="10.0.3.1-10.0.3.254"
# Same, but for IPs not intended to be exposed outside the firewall.
export PRIVATE_IP_RANGE="10.0.5.1-10.0.5.254"

# for Route53, which is hit by cert-manager in this config to prove domain
# ownership for letsencrypt
export AWS_REGION=us-east-1

# if specified, dex is configured to only claim the specified github org.
# if not specified, it will include all github ogs associated with the user.
export GITHUB_ORG=

# hostnames for the services
export DASHBOARD_HOST=dashboard
export DEX_ISSUER_HOST=auth
export KEYS_APP_HOST=keys

# probably don't want to modify these:

export SRC_DIR=$WORK_DIR/src

# dir into which volumes will be mounted and discovered by static-local-provisioner
export PERSISTENT_VOLUME_VOLS_DIR=/k8s-vols
export PERSISTENT_VOLUME_DISCO_DIR=/k8s-disco
export FIXED_SIZE_CLASS=fixed-size
export SCRATCH_CLASS=scratch

# unless you want set up a second nginx-ingress controller to run on some odd
# port number, leave this at 443.
export DEX_PORT=443
export DEX_ISSUER_FQDN=$DEX_ISSUER_HOST.$PRI_DOMAIN
export DEX_ISSUER_URL=https://$DEX_ISSUER_FQDN:$DEX_PORT
export KEYS_APP_FQDN=$KEYS_APP_HOST.intranet.$PRI_DOMAIN
export KEYS_APP_URL=https://$KEYS_APP_FQDN

export SSCERT=$WORK_DIR/sealed-secrets/sealed-secrets-cert.pem

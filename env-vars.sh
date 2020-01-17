########################################################################################################
########################################################################################################

# env-vars.sh

########################################################################################################
########################################################################################################

GIT_CONFIG_USERNAME=
GIT_CONFIG_EMAIL=

CLUSTER_NAME=my-cluster

# If your lan isn't 10.0.0.0/16, or your host isn't 10.0.0.10, you'll need to modify these.

# The kubernetes master node IP address in the lan on which host runs
ADVERTISE_ADDR="10.0.0.10"

# IP to be assigned by metallb for the nginx-controller service
LB_IP="10.0.1.1"

# IP range for metallb to assign to ingresses which should be exposed separately from the nginx-ingress.
PUBLIC_IP_RANGE="10.0.3.1-10.0.3.254"

# Same, but for IPs not intended to be exposed outside the firewall.
PRIVATE_IP_RANGE="10.0.4.1-10.0.4.254"

# for Route53, which is hit by cert-manager
AWS_REGION=us-east-1

WORK_DIR=$HOME/setup-kubernetes

# all of the dns names created will be children of this domain
PRI_DOMAIN=example.com

# if specified, restricts logins to a github org
GITHUB_ORG=

# hostnames for the services
DASHBOARD_HOST=dashboard
DEX_ISSUER_HOST=login
GANGWAY_HOST=gangway
KEYS_APP_HOST=keys

KUBE_ADMIN_USER=me@example.com

# unless you want set up a second nginx-ingress controller to run on some odd
# port number, leave this at 443.
DEX_PORT=443

SRC_DIR=$WORK_DIR/src
DEX_ISSUER_FQDN=$DEX_ISSUER_HOST.$PRI_DOMAIN
DEX_ISSUER_URL=https://$DEX_ISSUER_FQDN:$DEX_PORT
GANGWAY_URL=https://$GANGWAY_HOST.$PRI_DOMAIN

SSCERT=$WORK_DIR/sealed-secrets/sealed-secrets-cert.pem

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

# If your lan isn't 10.0.0.0/16, and/or your host isn't 10.0.0.10, you'll need
# to modify these.

# The kubernetes master node IP address in the lan on which host runs
export ADVERTISE_ADDR="10.0.0.10"

# IP to be assigned by metallb for the nginx-controller service
export LB_IP="10.0.1.1"

# IP range for metallb to assign to ingresses which should be exposed separately
# from the nginx-ingress.
export PUBLIC_IP_RANGE="10.0.3.1-10.0.3.254"

# Same, but for IPs not intended to be exposed outside the firewall.
export PRIVATE_IP_RANGE="10.0.4.1-10.0.4.254"

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

# unless you want set up a second nginx-ingress controller to run on some odd
# port number, leave this at 443.
export DEX_PORT=443
export DEX_ISSUER_FQDN=$DEX_ISSUER_HOST.$PRI_DOMAIN
export DEX_ISSUER_URL=https://$DEX_ISSUER_FQDN:$DEX_PORT
export KEYS_APP_FQDN=$KEYS_APP_HOST.$PRI_DOMAIN
export KEYS_APP_URL=https://$KEYS_APP_FQDN

export SSCERT=$WORK_DIR/sealed-secrets/sealed-secrets-cert.pem

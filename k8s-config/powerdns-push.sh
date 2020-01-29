########################################################################

# powerdns-push.sh

########################################################################

# have to wait until after we've build the docker-registry,
# AND we've configured dns, in order to be able to push to the registry.
# Thus, this is called later in the setup.

sudo podman push docker-registry.intranet.$PRI_DOMAIN/powerdns:debian-buster-slim

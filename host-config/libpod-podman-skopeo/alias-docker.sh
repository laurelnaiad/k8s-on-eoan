########################################################################

# alias-docker.sh

########################################################################

# make the `docker` command in-fact call `sudo podman`
echo "alias docker=\"sudo podman\"" | tee ~/.profile
source ~/.profile

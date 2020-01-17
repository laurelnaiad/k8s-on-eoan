########################################################################

# git-config.sh

########################################################################
git config --global user.name $GIT_CONFIG_USERNAME
git config --global user.email $GIT_CONFIG_EMAIL
git config --global credential.helper cache
git config --global credential.helper 'cache --timeout=31536000'

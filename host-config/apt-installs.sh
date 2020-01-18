########################################################################

# apt-installs.sh

# These are the combined dependences of the packages that are built from
# source or otherwise manually installed in this setup.

# crio supposedly needs cri-o-runc on Ubuntu. That appears to be a fork of runc.
# It has no Ubuntu Eoan package. I tried running without it (latest runc is
# being installed by these scripts, anway), and seem to be running ok.

# TODO: make notes of which component needs which of these packages.

########################################################################

sudo apt-add-repository ppa:projectatomic/ppa
sudo apt-get update -qq && sudo apt-get install -y \
  autoconf \
  automake \
  build-essential \
  conntrack \
  fuse3 \
  gcc \
  git \
  go-md2man \
  iptables \
  libapparmor-dev \
  libassuan-dev \
  libbtrfs-dev \
  libc6-dev \
  libcap-dev \
  libdevmapper-dev \
  libfuse3-dev
  libgpg-error-dev \
  libgpgme-dev \
  libglib2.0-dev \
  libprotobuf-dev \
  libprotobuf-c-dev \
  libseccomp-dev \
  libselinux1-dev \
  libsystemd-dev \
  libtool \
  libudev-dev \
  libyajl-dev \
  make \
  ninja-build \
  pkgconf \
  python3 \
  python3-pip \
  python3-setuptools \
  python3-wheel \
  slirp4netns \
  socat \
  software-properties-common

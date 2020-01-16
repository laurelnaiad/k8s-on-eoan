########################################################################

# varlink-install.sh

# varlink is required for podman remote

########################################################################
MYDIR=$SRC_DIR/libvarlink

git clone https://github.com/varlink/libvarlink $MYDIR
cd $MYDIR
sudo apt-get install
python3 -m pip install meson
sudo python3 -m pip install meson
make
sudo make install
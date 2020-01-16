########################################################################

# golang-install.sh

########################################################################
wget -P $WORK_DIR/tars https://dl.google.com/go/go1.13.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf tars/go1.13.5.linux-amd64.tar.gz

cat <<EOF | sudo tee -a ~/.profile
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
EOF

# add :/usr/local/go/bin to the secure_path, otherwise sudo make will fail to find go.
cat <<EOF | sudo tee /etc/sudoers.d/go-path
# adding /usr/local/go/bin
Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/usr/local/go/bin"
EOF
sudo chmod 0440 /etc/sudoers.d/go-path

source ~/.profile

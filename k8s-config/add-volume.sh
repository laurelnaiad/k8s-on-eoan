########################################################################

# add-volume.sh

########################################################################

########################################################################
# scratch volume mounts
########################################################################
# under default env-vars,
# export PERSISTENT_VOLUME_VOLS_DIR=/k8s-vols
# export PERSISTENT_VOLUME_DISCO_DIR=/k8s-disco
# export PERSISTENT_VOLUME_GROUP=ubuntu-vg
# ...
# and called as `add_volume fixed-size 2GB myuser mygroup 770` **for the third time**...
# creates a 2GB logical volume at:
#   /dev/ubuntu-vg/k8s-fixed-size-vol-002-lv    <= 002 because this is the third vol of this class
# mounted at:
#   /k8s-disco/fixed-size/vol-002-f8ee6706-ce5a <- it will be some other partial uuid
# which would be owned by:
#   myuser:mygroup
# with permissions:
#   drwxrwx---
function add_volume() {
  CLASSNAME=$1
  SIZE=$2
  OWNER_UID=$3
  if [[ -n "$4" ]]; then OWNER_GID=$4; else OWNER_GID=$3; fi
  if [[ -n "$5" ]]; then PERMS=$5; else PERMS="770"; fi

  LVCOUNT=$(sudo lvs | grep k8s-vol-$CLASSNAME | wc -l)
  VOLNUM=printf %03d $LVCOUNT
  VOLNAME=k8s-$CLASSNAME-vol-$VOLNUM-lv
  sudo lvcreate -L +${SIZE} -n $VOLNAME $PERSISTENT_VOLUME_GROUP
  MYDEV=/dev/$PERSISTENT_VOLUME_GROUP/$CLASSNAME-vol-$VOLNUM
  sudo mkfs.ext4 $MYDEV
  sudo e2label $MYDEV k8s-$CLASSNAME-vol-$VOLNUM
  MY_VOL_UUID=$(sudo blkid -s UUID -o value $MYDEV)
  MY_SHORT_UUID=$(echo "$MY_VOL_UUID" | awk -F"-" '{print $1 "-" $2}')
  MY_VOL_DIR=$PERSISTENT_VOLUME_DISCO_DIR/$CLASSNAME/vol-$VOLNUM-$MY_SHORT_UUID
  sudo mkdir -p $MY_VOL_DIR
  sudo mount -t ext4 $MYDEV $MY_VOL_DIR
  sudo chmod $PERMS $MY_VOL_DIR
  sudo chown $OWNER_UID:$OWNER_GID $MY_VOL_DIR
  echo UUID=$MY_SHORT_UUID $MY_VOL_DIR ext4 defaults 0 2 | sudo tee -a /etc/fstab
}

########################################################################

# scratch-volume=mounts.sh

########################################################################

# under default env-vars,
# export PERSISTENT_VOLUME_GROUP=ubuntu-vg
# export PERSISTENT_VOLUME_VOLS_DIR=/k8s-vols
# export PERSISTENT_VOLUME_DISCO_DIR=/k8s-disco
# export FIXED_SIZE_CLASS=fixed-sized
# export SCRATCH_CLASS=scratch
# ...
# create a 1GB logical volume at:
#   /dev/ubuntu-vg/k8s-vol-scratch-lv
# mounted at:
#   /k8s-vols/scratch-f8ee6706-ce5a <- it will be some other partial uuid
# with subdirs vol0 through vol9, which are bind-mounted as:
#   /k8s-disco/scratch/vol-000-f8ee6706-ce5a
#   ...
#   /k8s-disco/scratch/vol-009-f8ee6706-ce5a
# such that a StorageClass named scratch can use /k8s-mounts/scratch as its discodir,
# thus providing 10 local volumes sharing 1GB.
sudo mkdir -p $PERSISTENT_VOLUME_VOLS_DIR
sudo mkdir -p $PERSISTENT_VOLUME_DISCO_DIR/$FIXED_SIZE_CLASS
sudo mkdir -p $PERSISTENT_VOLUME_DISCO_DIR/$SCRATCH_CLASS
sudo chmod 755 $PERSISTENT_VOLUME_VOLS_DIR $PERSISTENT_VOLUME_DISCO_DIR $PERSISTENT_VOLUME_DISCO_DIR/*

MY_CLASS_NAME=$SCRATCH_CLASS

sudo lvcreate -L +1G -n k8s-$MY_CLASS_NAME-lv $PERSISTENT_VOLUME_GROUP
MYDEV=/dev/$PERSISTENT_VOLUME_GROUP/k8s-$MY_CLASS_NAME-lv
sudo mkfs.ext4 $MYDEV
sudo e2label $MYDEV k8s-$MY_CLASS_NAME
MY_VOL_UUID=$(sudo blkid -s UUID -o value $MYDEV)
# grab first two segments of UUID
MY_SHORT_UUID=$(echo "$MY_VOL_UUID" | awk -F"-" '{print $1 "-" $2}')
MY_VOL_DIR=$PERSISTENT_VOLUME_VOLS_DIR/$MY_CLASS_NAME-$MY_SHORT_UUID
sudo mkdir -p $MY_VOL_DIR
sudo chmod 755 $MY_VOL_DIR
sudo mount -t ext4 $MYDEV $MY_VOL_DIR
echo UUID=$MY_VOL_UUID $MY_VOL_DIR ext4 defaults 0 2 | sudo tee -a /etc/fstab
for i in $(seq 0 9); do
  NUM=$(printf %03d $i)
  MYDIRNAME=$MY_CLASS_NAME/vol-${NUM}-$MY_SHORT_UUID
  sudo mkdir -p $MY_VOL_DIR/vol-${NUM} $PERSISTENT_VOLUME_DISCO_DIR/$MYDIRNAME
  sudo mount --bind $MY_VOL_DIR/vol-${NUM} $PERSISTENT_VOLUME_DISCO_DIR/$MYDIRNAME
  # it's called scratch for a reason... these dirs are up for grabs
  sudo chmod 777 $PERSISTENT_VOLUME_DISCO_DIR/$MYDIRNAME
  echo $MY_VOL_DIR/vol-${NUM} $PERSISTENT_VOLUME_DISCO_DIR/$MYDIRNAME none bind 0 0 | sudo tee -a /etc/fstab
done

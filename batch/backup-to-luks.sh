#!/usr/bin/env bash

USER=$(logname)
HOST=127.0.0.1
IMAGE=backup.img
DEV=${IMAGE%.*}

BACKUP=/mnt/$DEV
TARGET=/home

function stdout(){
   while read TEXT; do
      echo "   (-) $TEXT"
   done < $1
}

function stderr(){
   while read TEXT; do
      echo "   (E) $TEXT"
   done < $1
}

if [ ! -d "$TARGET" ]; then
   echo "[E] not valid backup target"
   exit 1
fi

if [ "0" -ne "$UID" ]; then
   echo "[E] only root can do it!"
   exit 1
fi

# create temporary files used for standard file streams redirection
TMPO=$(mktemp)
TMPE=$(mktemp)

# create the remote mount point
echo -e "\n>> creating the remote mount point:"
sudo -u$USER ssh -t $USER@$HOST sudo mkdir -pv $BACKUP >$TMPO 2>$TMPE
ERR=$?
stdout $TMPO
stderr $TMPE

if [ "0" -ne "$ERR" ]; then
   echo "   (E) cannot create the mount point (error code $ERR)"
   exit $ERR
fi

# open the crypted container (mapping)
echo -e "\n>> opening the remote (crypted) container:"
sudo -u$USER ssh -t $USER@$HOST sudo cryptsetup luksOpen ~/$IMAGE $DEV 2>$TMPE
ERR=$?
stderr $TMPE

if [ "0" -ne "$ERR" ]; then
   echo "   (E) cannot open the LUKS container (error code $ERR)"
   exit $ERR
fi

# mount the remote block device
echo
echo -e ">> mounting the remote block device:"
sudo -u$USER ssh -t $USER@$HOST sudo mount /dev/mapper/$DEV $BACKUP >$TMPO 2>$TMPE
ERR=$?
stdout $TMPO
stderr $TMPE

if [ "0" -ne "$ERR" ]; then
   echo "   (E) cannot mount the crypted device (error code $ERR)"
   exit $ERR
fi

# backup $TARGET directory using rsync
echo -e "\n>> synchronizing backup and target directories:"

for i in $TARGET/*; do
	OPTIONS="--exclude-from="/home/$USER/.excluded.txt" --delete-excluded --delete-after -avzH --partial --inplace --numeric-ids"
	echo sudo -u$USER rsync $OPTONS -e ssh "$i/" "$USER@$HOST:$BACKUP/${i/\/home\//}"
	sudo -u$USER rsync $OPTIONS -e ssh "$i/" "$USER@$HOST:$BACKUP/${i/\/home\//}"
done

# umount the remote block device
echo -e "\n>> unmounting the remote block device:"
sudo -u$USER ssh -t $USER@$HOST sudo umount $BACKUP >$TMPO 2>$TMPE
ERR=$?
stdout $TMPO
stderr $TMPE

if [ "0" -ne "$ERR" ]; then
   echo "   (E) cannot unmuount the crypted device (error code $ERR)"
fi

# close the crypted container (mapping)
echo -e "\n>> closing the remote (crypted) container:"
sudo -u$USER ssh -t $USER@$HOST sudo cryptsetup luksClose $DEV >$TMPO 2>$TMPE
ERR=$?
stdout $TMPO
stderr $TMPE

if [ "0" -ne "$ERR" ]; then
   echo "   (E) cannot close the LUKS container (error code $ERR)"
fi

# remove the destination folder
echo -e "\n>> delete the remote mount point"
sudo -u$USER ssh -t $USER@$HOST sudo rmdir $BACKUP >$TMPO 2>$TMPE
ERR=$?
stdout $TMPO
stderr $TMPE

if [ "0" -ne "$ERR" ]; then
   echo "   (E) cannot create the mount point (error code $ERR)"
fi

# clean up
rm $TMPO $TMPE

# all ok
echo -e "\n>> backup completed!\n"
exit 0

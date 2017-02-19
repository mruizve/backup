#!/usr/bin/env bash

USER=$(logname)
BACKUP=/media/backup
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

if [ ! -d "$BACKUP" ]; then
   echo "[E] not valid backup destination"
   exit 1
fi

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

# mount file system based on /etc/fstab entry
echo -e "\n>> mounting backup file system:"
mount -v "$BACKUP" >"$TMPO" 2>"$TMPE"
ERR=$?
stdout $TMPO
stderr $TMPE

if [ "0" -ne "$ERR" ]; then
   umount $BACKUP 2>&1 >/dev/null
   echo -e "   (E) cannot mount backup file system (error code $ERR)\n"
   exit $ERR
fi

# backup $TARGET directory using rsync
echo -e "\n>> synchronizing backup and target directories:"

for i in $TARGET/*; do
	OPTIONS="--exclude-from="/home/$USER/.excluded.txt" --delete-excluded --delete-after -avzH --partial --inplace --numeric-ids"
	echo rsync $OPTIONS  "$i/" "$BACKUP/${i/\/home\//}"
	rsync $OPTIONS "$i/" "$BACKUP/${i/\/home\//}"
done

# umount backup file system
echo -e "\n>> unmounting backup file system:"
umount -v $BACKUP >$TMPO 2>$TMPE
stdout $TMPO
stderr $TMPE

if [ "0" -ne "$ERR" ]; then
	echo -e "   (E) cannot umount backup file system (error code $ERR)\n"
	exit $ERR
fi

# clean up
rm $TMPO $TMPE

# all ok
echo -e "\n>> backup completed!\n"
exit 0

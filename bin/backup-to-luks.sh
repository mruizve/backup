#!/usr/bin/env bash

USER="$(logname)"
HOST="127.0.0.1"
IMAGE="backup.img"
DEV="${IMAGE%.*}"

SRC="/home/$USER"
DST="/mnt/$DEV"

SSH="ssh -t $USER@$HOST"

if [ ! -d "$SRC" ]; then
	echo "(E) invalid source target"
	exit 1
fi

# load common functions
if [ ! -f "$(dirname "$0")/backup-common.sh" ]; then
	echo "(E) missing backup-common definitions"
	exit 1
fi
source "$(dirname "$0")/backup-common.sh"

# overwrite trap handlers
function luks-cleanup()
{
	# retrieve exit code
	code="$?"
	
	# on error, try to unmount and close the crypted container
	if [ 0 -ne "$code" ]; then
		ssh -t "$USER@$HOST" sudo umount "$DST" >/dev/null 2>&1
		ssh -t "$USER@$HOST" sudo cryptsetup luksClose "$DEV" >/dev/null 2>&1
		ssh -t "$USER@$HOST" sudo rmdir "$DST" >/dev/null 2>&1
	fi

	# manually call the cleanup handler
	backup-cleanup "$code"
}

trap luks-cleanup INT TERM EXIT ERR

# create the remote mount point (if necessary)
TYPE=1 backup-exec "creating the remote mount point" '$SSH sudo mkdir -p "$DST"'

# open the crypted container (mapping)
TYPE=0 backup-exec "opening the remote LUKS container" '$SSH sudo cryptsetup luksOpen "~/$IMAGE" "$DEV"'

# mount the remote block device
TYPE=1 backup-exec "mounting the remote block device" '$SSH sudo mount "/dev/mapper/$DEV" "$DST"'

# log headers
echo "# src: $SRC/" >> "$LOGGER"
echo "# dst: $USER@$HOST:$DST/" >> "$LOGGER"
echo >> "$LOGGER"

# backup source directory using rsync
TYPE=2 backup-exec "synchronizing '$USER@$HOST:$DST/' with '$SRC/'" '$RSYNC -z -e ssh "$SRC/" "$USER@$HOST:$DST/"'

# umount the remote block device
TYPE=1 backup-exec "unmounting the remote block device" '$SSH sudo umount "$DST"'

# close the crypted container (mapping)
TYPE=1 backup-exec "closing the remote LUKS container" '$SSH sudo cryptsetup luksClose "$DEV"'

# remove the destination folder
TYPE=1 backup-exec "deleting the remote mount point" '$SSH sudo rmdir "$DST"'

# all ok
echo ">> backup completed!"

exit 0

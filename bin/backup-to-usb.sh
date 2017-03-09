#!/usr/bin/env bash

USER="$(logname)"

SRC="/home/$USER"
DST="/media/backup"

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
function usb-cleanup()
{
	# retrieve exit code
	code="$?"

	# on error, try to unmount the block device
	if [ 0 -ne "$code" ]; then
		umount "$DST" >/dev/null 2>&1
		sudo rmdir "$DST" >/dev/null 2>&1
	fi

	# manually call the cleanup handler
	backup-cleanup "$code"
}

trap usb-cleanup INT TERM EXIT ERR

# create the remote mount point (if necessary)
TYPE=1 backup-exec "creating the backup mount point" 'sudo mkdir -p "$DST"'

# mount usb block device based on the /etc/fstab entry
TYPE=1 backup-exec "mounting the usb block device" 'mount "$DST"'

# log headers
echo "# src: $SRC/" >> "$LOGGER"
echo "# dst: $DST/" >> "$LOGGER"
echo >> "$LOGGER"

# backup source directory using rsync
TYPE=2 backup-exec "synchronizing '$DST/' with '$SRC/'" '$RSYNC "$SRC/" "$DST/"'

# umount the usb block device
TYPE=1 backup-exec "unmounting the usb block device" 'umount "$DST"'

# remove the destination folder
TYPE=1 backup-exec "deleting the backup mount point" 'sudo rmdir "$DST"'

# all ok
echo ">> backup completed!"

exit 0

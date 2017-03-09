#!/usr/bin/env bash

# excluded and logging files
IGNORE="/home/$USER/.backup/excluded.txt"
LOGGER="/home/$USER/.backup/batch/$(date '+%s').log"

# create temporary files used for standard file streams redirection
TMPO="$(mktemp)"
TMPE="$(mktemp)"

# rsync options for backup
OPTIONS=(--exclude-from="$IGNORE" --delete-excluded -av)

# robustly execute commands and show formatted output and error messages
function backup-exec()
{
	RED="\033[1;31m"
	WHT="\033[0;37m"

	# clear output file
	>"$TMPO"

	case "$TYPE" in
		2) # log command outcome
			printf ">> $1... "

			eval $2 >"$LOGGER" 2>"$TMPE"
			;;

		1) # show formatted command outcome
			printf ">> $1... "

			eval $2 >"$TMPO" 2>"$TMPE"
			;;

		0) # interactive command outcome
			echo ">> $1... "

			TMPI="$(mktemp -u)"
			mkfifo "$TMPI"

			"$(dirname "$0")/cat" < "$TMPI" &
			eval $2 2>"$TMPE" >"$TMPI"
			;;
	esac

	# retrieve the last exit code
	code=$?

	# show command status?
	if [ "0" -ne "$TYPE" ]; then
		# got an error?
		if [ "0" -ne "$code" ]; then
			echo -e $RED"failure"$WHT"!"
		else
			echo "done!"
		fi
	fi

	# show the standard output
	while read TEXT; do
		echo "   (-) $TEXT"
	done < "$TMPO"

	# error details (if any)
	if [ "0" -ne "$code" ]; then
		# show the standard error
		while read TEXT; do
			echo "   (E) $TEXT"
		done < "$TMPE"

		# print the error message
		echo "   (E) exit code: $code"

		# exit with failure
		exit $code
	fi
}

function backup-cleanup()
{
	# retrieve exit code
	code="$?"
	
	# this function have been manually called?
	if [ "1" -eq "$#" ]; then
		code="$1"
	fi

	# clean up
	rm "$TMPO" "$TMPE"

	exit $code
}

trap backup-cleanup INT TERM EXIT ERR

# create the logging directory (if necessary)
TYPE=1 backup-exec "creating the logging directory" 'mkdir -pv "${LOGGER%/*}"'

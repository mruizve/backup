#!/usr/bin/env bash

# get script name
script=${0##*/}
script=${script%.*}

# generate a random prefix
prefix=~/."$(cat /dev/urandom| tr -dc A-Za-z0-9\-_\!\@\#$\%\(\)-| head -c 16)-"

# commands and functions
secret='cat'
encrypt='gpg --armor --passphrase "$passphrase" -c 2>/dev/null'
split='split -a2 -d -b 2500 - "$prefix"'

encode()
{
	for i in "$prefix"*; do
		filename="$outdir/$1-${i##*-}.png"
		qrencode -s3 -d300 -o "$filename" < "$i"
		chmod 600 "$filename"
		shred -zun30 "$i"
	done
}

# get storage encryption passphrase
passpath=~/.passwords/storage.asc
if [ -e "$passpath" ]; then
	passphrase=$(gpg -q --no-verbose --decrypt "$passpath" 2>/dev/null)

	if [ "$?" -ne "0" ]; then
		echo "[$script|error] cannot retrieve the storage passphrase."
		exit 1
	fi
else
	echo "[$script|error] storage passphrase is missing."
	exit 1
fi

# for each target
for target in {gpg,password,ssh}; do
	# create destination folders
	outdir=~/.backup/$target
	mkdir -p -m700 $outdir

	# list of secret keys
	keys=""
	secret='cat'

	if [ "gpg" = "$target" ]; then 
		# get list of GPG secret keys
		keys=$(gpg --list-secret-keys |grep ^sec|awk '{printf "%s\n",substr($2,7)}')

		# change default secret action
		secret='gpg --armor --export-secret-keys'
	fi

	if [ "password" = "$target" ]; then
		# for each stored password,
		for i in ~/.passwords/*.asc; do
			# extract file name
			filename="${i##*/}"
			filename="${filename%.*}"

			# do not export $passpath
			if [ "$i" = "$passpath" ]; then
				echo "password $filename skipped."
			else
				# export and encrypt the password and split data in chunks of 2500 bytes
				eval $secret $i|eval $encrypt|eval $split

				# encode each file chunk into a qr image and delete the gpg sources
				printf "encoding password $filename... "
				encode "$filename"
				echo "done!"
			fi
		done
	fi

	if [ "ssh" = "$target" ]; then 
		# get list of SSH secret keys
		keys=$(find ~/.ssh -type f -name '*_rsa')

		# if the .ssh/config file is defined, then
		config=~/.ssh/config
		if [ -e "$config" ]; then
			# export and encrypt the config file and split data in chunks of 2500 bytes
			eval $secret $config|eval $encrypt|eval $split

			# encode each file chunk into a qr image and delete the split sources
			printf "encoding file ~/.ssh/config... "
			encode "config"
			echo "done!"
		fi
	fi

	if [ -n "$keys" ]; then
		# for each secret key,
		for i in $keys; do
			# export and encrypt the key and split data in chunks of 2500 bytes
			eval $secret $i|eval $encrypt|eval $split

			# encode each file chunk into a qr image and delete the split sources
			printf "encoding $target key ${i##*/}... "
			encode "${i##*/}"
			echo "done!"
		done
	fi
done

# "delete" key
passphrase=""

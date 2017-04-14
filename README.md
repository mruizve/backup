# backup
This is a quite incomplete (and on a very early stage) collection of scripts for personal data backup and some password handling tools.
The backup scripts are divided in three main functionalities

1. Batch data synchronization based on ```rsync```, for simple backup between local or remote devices.
Including
* ```backup-to-usb.sh```: data synchronization with a **local** USB disk connected to the computer.
* ```backup-to-luks.sh```: data synchronization with a **remote** LUKS device (that can be a hard disk or an image file).

**Warning**: we use the rsync ```--delete-excluded``` flag on both scripts!

2. Conversion of secret GPG/SSH keys and other sensible encrypted data into QR codes for physical backup and storage.
Currently this functionality is implemented in ```backup-qr-secrets.sh```.

3. Passwords handling, which is still under design, implementation and development, reason why a clear and introductory description is almost impossible as well as useless.

## Batch data synchronization

The scripts are very simple and are rely in the following set of assumptions 

Common assumptions

1. The regular file ```~/.backup/excluded.txt``` exists and consists on a (possibly empty) list of paths patterns to be exclude from the backup.
2. The ```$SRC``` variable defines a valid path on the local file system structure.
3. The login user is the owner of the data contained in ```$SRC```.
4. All transfer outcomes (standard output content) is written into a log file created inside the folder ```~/.backup/batch/XXXXXXXX.log```, where ```XXXXXXXX``` is a timestamp in epoch time.

```backup-to-usb.sh``` assumptions

1. The backup device is connected to the PC and is NOT mounted.
2. The login user have writing permission on the backup device.
3. The ```$DST``` variable defines a predefined mount point on /etc/fstab associated to the backup device.
4. Data will be synchronized to ```$DST/$USER/``` instead of ```$DST/```.

```backup-to-luks.sh``` assumptions

1. The ```cryptsetup``` tools are installed on the remote host.
2. The remote host's IP or DNS is given in the ```$HOST``` variable.
3. The login user have a valid account with granted ssh access on ```$HOST```.
4. On the user's remote home exist either a regular image file or a block device, named ```$IMAGE```, holding the LUKS file system.


## QR-secrets

This script is still on embryonic state and could suffer a deep metamorphosis in the _near future_ updates.
The script is based on the following set of assumptions

1. The folder ```~/.passwords``` exists and holds different ASCII armored GPG encrypted files.
2. All files in ```~/.passwords``` have the ```.asc``` extension or only those files will be encoded for physical backup.
3. Since the data feed to the QR encoder is encrypted with a passphrase using the AES algorithm, it is assumed that in ```~/.passwords``` there is at least one encrypted file named ```storage.asc``` storing such passphrase (a rational alternative should be to kindly ask the user for a passphrase, but rather than implementing a mechanism for verifying that the user inserted the desired passphrase without misspelling it, we let GPG do the work during the file decryption; after that we have the unique passphrase given by the file content).
4. The following files will be converted
    * Secret GPG keys in armored ASCII format, encrypted with the storage passphrase.
    * Secret SSH keys in armored ASCII format and the ```.ssh/config``` file, all encrypted with the storage passphrase.
    * All files in the folder ```.passwords``` having the extension ```.asc``` (assumed to be ASCII armored GPG encrypted files), except the ```storage.asc``` one, all of them encrypted with the storage passphrase.
5. Generated QR codes are stored on the folder ```~/.backup/qr/```.

## Passwords handling

The idea is to provide a simple tool (a script and a binary file) for decrypting passwords files using GPG, copying the decrypted passphrase to the clipboard and removing it after the first paste action or when some predefined timeout has been reach.

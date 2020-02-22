localfolder=/home/
remotefolder=/

#Clear Log Files
echo " " > /etc/backup/backupscript/backup.log

#Backup the files to a remote location
rclone sync $localfolder backupscript:$remotefolder --progress -q --log-file=/etc/backup/backupscript/backup.log

exit 0
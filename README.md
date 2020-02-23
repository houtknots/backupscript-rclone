# Backupscript rclone
 Backupscript based on [RClone](https://rclone.org/ "rclone.org")

Run the following commando to download and run the installer 
```bash
sudo curl https://raw.githubusercontent.com/houtknots/backupscript-rclone/master/installer.sh -o installer.sh && sudo bash installer.sh
```

The backup script will be installed in ```/etc/backup/backupscript/```
<<<<<<< HEAD

If you want to run the script manually u can use the command below 
```sudo bash /etc/backup/backupscript/backup.sh```

# Current Features
* ZIP
* WebDav | FTP | SFTP 
* Daily Cronjob
* Retention

# Features Planed to be added/remade
* Graphical menu (commandline menu)
* Uninstall Feature
* History Log
* Backup restore function
* Add option for TAR instead of ZIP
* Notifications via Webhooks (Slack,Discord)
* Notifications via Email
* Checking for updates
* Error Handling
* Backup to Openstack Swift
* Backup with RSYNC

# Known bugs
* SFTP not working correctly 

May you have any suggestions please create an issue with the *Suggestion* label.
=======
If you want to run the script u can use the command below

```sudo bash /etc/backup/backupscript/backup.sh```
>>>>>>> 05df6d12f056eb7fb4f7a287a11ec08a3b509d12

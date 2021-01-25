#!/bin/sh

# Project: Rclone backup script
# Author : houtknots
# Website: https://houtknots.com/
# Github : https://github.com/houtknots

##########################################################
#					   Start Script				         #
##########################################################

#Define color codes
RED='\033[1;31m'				#Color Red in echo
GREEN='\033[1;32m'				#Color GREEN in echo
CYAN='\e[36m'					#Color CYAN in echo
YELLOW='\e[33m'					#Color YELLOW in echo
BLUE='\e[34m'					#Color BLUE in echo
NC='\033[0m'					#Remove Colors in echo

#Check the date
#DATE=$(date +"%Y-%m-%d_%H-%M-%S")

#Get Server Hostname
hostname_server="`hostname`"

#Check if the user is root or runs the script with sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Please run the script as root ${NC}- Try to run with sudo or as root user"
   exit 1
fi

function_createfolders () {
	#Check if needed folders exist and create them if they do not exist
	if [ ! -d "/usr/local/backupscript" ]; then
       		echo -e "${YELLOW}Creating Backupscript folder...${NC}"
       		mkdir /usr/local/backupscript
	fi
}

function_installpackages () {
	#Check to OS and declare the package installer
	declare -A osInfo;
		osInfo[/etc/redhat-release]=yum
		osInfo[/etc/arch-release]=pacman
		osInfo[/etc/gentoo-release]=emerge
		osInfo[/etc/debian_version]=apt-get

	for f in ${!osInfo[@]}
	do
	   	if [[ -f $f ]];then
       		echo Package manager: ${osInfo[$f]}
       		PKGINSTALLER="${osInfo[$f]}"
    	fi
	done	

	#Install required packages
	$PKGINSTALLER install zip -y
	$PKGINSTALLER install unzip -y
	$PKGINSTALLER install curl -y
	curl https://rclone.org/install.sh | sudo bash

	#Download backupscript from github
	if [ ! -f "/usr/local/backupscript/backup.sh" ]; then
		curl https://raw.githubusercontent.com/houtknots/backupscript-rclone/master/backup.sh -o /usr/local/backupscript/backup.sh
	fi
}


function_newconfig () {
	#ask if the user wants to purge the old config, otherwise abort script
	while [ "$newconfig_continue" != "true" ]; do
		echo -e "${YELLOW}Would you like to continue, this will remove your current backupscript rclone config!?${NC}"
		read -p '[OVERWRITE CONFIG] (y/n): ' newconfig
			case $newconfig in
  			y|Y) 
				newconfig_continue="true"
				rclone config delete backupscript
				#Check if the cronjob allready exists, if so clear the content
				if [ -f /etc/cron.d/backupscript ];
				then
					true > /etc/cron.d/backupscript
				fi
			;;
	  		n|N)
				echo "Please edit the backup config directly within the script /usr/local/backupscript/backup.sh"
				newconfig_continue="true"
				exit 0
			;;
  			*) 	
				echo "Please enter y or n to continue"
				newconfig_continue="false"
			;;  
			esac
	done
	clear
}

function_protocol () {
	#Ask the user which protocol he or she wants to use for the file transfer
	echo -e "${YELLOW}Please select the ${CYAN}protocol ${YELLOW}you would like to use.?${NC}"
	echo -e " [1] - WebDav"
	echo -e " [2] - SFTP "
	echo -e " [3] - FTP"
#	echo -e " [4] - RSYNC"
#	echo -e " [5] - OPENSTACK SWIFT"
	echo -e " "
	read -e -p '[PROTOCOL]: ' -i "$protocol" protocol
	clear
}

function_hostname () {
	#Ask for the hostname
	echo -e "${YELLOW}Please enter your ${CYAN}remote hostname or IP ${YELLOW}and press enter - the backup will be made to this location${NC}"
		read -e -p '[HOSTNAME]: ' -i "$hostname" hostname
	clear
}

function_username () {
	#Ask for the remote destination username
	echo -e "${YELLOW}Please enter your ${CYAN}remote user ${YELLOW}and press enter${NC}"	
		read -e -p '[USERNAME]: ' -i "$username" username
	clear
}

function_password () {
	#Ask for the remote destination password
	echo -e "${YELLOW}Please enter your ${CYAN}remote password${NC} ${YELLOW}and press enter${NC}"		
		read -sp '[PASSWORD]: ' password
	clear
}

function_localfolder () {
	#Ask which files to backup
	echo -e "${YELLOW}Please enter the ${CYAN}local file location${NC} ${YELLOW}you want to backup and press enter${NC}"
		read -e -p '[LOCAL FOLDER]: ' -i "/home/" localfolder
	clear
}

function_tempfolder () {
	#Ask which files to backup
	echo -e "${YELLOW}Please enter the ${CYAN}local temporary location${NC} ${YELLOW}the backup will use before uploading and press enter${NC}"
		read -e -p '[LOCAL TEMPORARY FOLDER]: ' -i "/usr/local/backupscript/temp" tempfolder
	clear
}

function_remotefolder () {
	#Ask where to put the files on the remote side
	echo -e "${YELLOW}Please enter the ${CYAN}remote folder${NC} ${YELLOW}you want to put the backup${NC}"
		read -e -p '[REMOTE FOLDER]: ' -i "$hostname_server" remotefolder
	clear
}

function_remoteport () {
	#Ask which port to use for the remote connection
	echo -e "${YELLOW}Please enter the ${CYAN}remote port${NC} ${YELLOW}the scripts needs to contact the remote server on${NC}"
		read -e -p '[REMOTE PORT]: ' -i "22" remoteport
	clear
}

function_usezip () {
	#Ask if the user would like to use the zip function
	echo -e "${YELLOW}Would you like the use the zip function, this requires extra space on your local instance but uses less space on the remote side${NC}"
		read -e -p '[USE ZIP] (y/n): ' usezip
		case $usezip in
  			y|Y)
				usezip_value="true"
			;;
	  		n|N)
				usezip_value="false"
			;;
  			*) 
				usezip_value="false"
			;;
			esac
	clear
}

function_checksum () {
	#Ask if the user would like a md5 check 
	echo -e "${YELLOW}Would you like to use a ${CYAN}md5 check${NC} ${YELLOW}we only recommend this option if your localfolder does not use active changing${NC}"
		read -e -p '[USE CHECKSUM] (y/n): ' usechecksum
		case $usechecksum in
  			y|Y)
				usechecksum_value="true"
			;;
	  		n|N)
				usechecksum_value="false"
			;;
  			*) 
				usechecksum_value="false"
			;;
			esac
	clear
}

function_retention () {
	#Ask if the user wants to use retention on the remote server side
	while [ "$retention_continue" != "true" ]; do
	echo -e "${YELLOW}Would you like to purge old backups with the ${CYAN}retention${NC} ${YELLOW}feature? ${NC}"
		read -p '[RETENTION] (y/n): ' retention
			case $retention in
  			y|Y)
				retention_continue="true"
				retention_value="true"
				echo -e "${YELLOW}How many ${CYAN}days${NC} ${YELLOW}would you like to store the old backups before purging them?${NC}"
				read -e -p '[DAYS TO KEEP]: ' -i "14" retention_daystostore
			;;
	  		n|N)
				echo "Skipping Retention"
				retention_continue="true"
				retention_value="false"
				retention_daystostore="disabled"
			;;
  			*) 
				retention_continue="false"
			;;
			esac
		clear	
	done
}

function_notifications () {
	#Ask if the user wants to install a daily backup
	while [ "$notifications_continue" != "true" ]; do
	echo -e "${YELLOW}Would you like to use ${CYAN}notifications${NC} ${YELLOW}? - Discord ${NC}"
		read -p '[USE NOTIFICATIONS] (y/n): ' notifications
			case $notifications in
  			y|Y)
			  	notifications_continue="true"
				use_notifications="true"
			;;
	  		n|N)
			  	notifications_continue="true"
				use_notifications="false"
			;;
  			*) 
			  	notifications_continue="false"
				use_notifications="false"
			;;
			esac
		clear	
	done

	if [ "$use_notifications" == "true" ];
	then
		while [ "$notifications_discord_continue" != "true" ]; do
		echo -e "${YELLOW}Would you like to use ${CYAN}Discord${NC} ${YELLOW}notifcations? ${NC}"
			read -p '[USE DISCORD NOTIFICATIONS] (y/n): ' discordnotifications
				case $discordnotifications in
				y|Y)
					clear
					notifications_discord_continue="true"
					use_discordnotifications="true"
					read -p '[DISCORD WEBHOOK URL]: ' notifications_discordwebhook
				;;
				n|N)
					notifications_discord_continue="true"
					use_discordnotifications="false"
				;;
				*) 
					notifications_discord_continue="false"
					use_discordnotifications="false"
				;;
				esac
			clear	
		done
	fi


}

function_cronjob () {
	#Ask if the user wants to install a daily backup
	while [ "$cronjob_continue" != "true" ]; do
	echo -e "${YELLOW}Would you like to install a ${CYAN}Daily cronjob${NC} ${YELLOW}for automatic backups? ${NC}"
		read -p '[DAILY CRONJOB] (y/n): ' retention
			case $retention in
  			y|Y)
				cronjob_continue="true"
				cronjob_install="true"
			;;
	  		n|N)
				cronjob_continue="true"
				cronjob_install="false"
			;;
  			*) 
				cronjob_continue="false"
				cronjob_install="false"
			;;
			esac
		clear	
	done

}


#########################################################
#                  Configure Settings                   #
#########################################################

#Start the settings configuration
function_settings () {
	function_protocol #Ask which protocol to use
	function_hostname #Ask what hostname to use
	function_username #Ask what username to use
	function_password #Ask what password to use
	function_localfolder #Ask which folder to backup
	function_tempfolder #Ask which temp folder to use
	function_remotefolder #Ask where to place the backup on the remote side
	if [ "$protocol" == "2" ]; then function_remoteport; fi #Ask which port to use
	function_usezip #Ask to use ZIP of just upload the folder
	function_checksum
	function_retention #Ask if the users wants to use retention on the remote side
	function_notifications #Ask if the user want to use notifications
	function_cronjob #Ask if the users want to add a daily cronjob for automatic backups
}

#Ask if the user wants to create a new config
function_install () {
	function_createfolders
	function_installpackages
	function_newconfig
}

#Start the install function
function_install

#Start the settings function
function_settings

#########################################################
#                  Install Components                   #
#########################################################
while [ "$confirm_settings_continue" != "true" ]; do
	#Ask user if the settings are correct and install components
	echo -e "[PROTOCOL]: $protocol"
	echo -e "[HOSTNAME]: $hostname"
	echo -e "[USERNAME]: $username"
	echo -e "[PASSWORD]: *Hidden*"
	echo -e "[LOCAL FOLDER]: $localfolder "
	echo -e "[LOCAL TEMPORY FOLDER]: $tempfolder"
	echo -e "[REMOTE FOLDER]: $remotefolder"
	echo -e "[USE ZIP]:  $usezip_value"
	echo -e "[USE FILE CHECK]:  $usechecksum_value"
	echo -e "[RETENTION]: $retention_value"
	echo -e "[NOTIFICATIONS]: $use_notifications"
	echo -e "[DISCORD NOTIFICATIONS]: $use_discordnotifications"


	if [ "retention_value" == "true" ]; then echo -e "[RETENTION DAYS TO KEEP]: $retention_daystostore"; fi
	echo -e "[DAILY CRONJOB]: $cronjob_install"
	echo -e " "
	read -p 'Are the above values correct? (y/n): ' confirm_settings
		case $confirm_settings in
  		y|Y)
			confirm_settings_continue="true"
			confirm_settings_install="true"
		;;
	  	n|N)
			confirm_settings_continue="false"
			confirm_settings_install="false"
			echo -e "${RED}Please revisit your settings${NC}"
			sleep 2
			function_settings
		;;
  		*) 
			confirm_settings_continue="false"
			confirm_settings_install="false"
			echo -e "${RED}Invalid option provided${NC}"
			sleep 2
		;;
		esac
	clear	

done

if [ $confirm_settings_install == "true" ]; then
	#Create the RCLONE config with the selected protocol
	if [ "$protocol" != "${protocol#[1]}" ] ;then
	    echo -e "${GREEN}Webdav Selected${NC}"
		rclone config create backupscript webdav
	elif [ "$protocol" != "${protocol#[2]}" ] ;then
	    echo -e "${GREEN}SFTP Selected${NC}"
		rclone config create backupscript sftp
	elif [ "$protocol" != "${protocol#[3]}" ] ;then
		echo -e "${GREEN}FTP Selected${NC}"
		rclone config create backupscript ftp
	else
		echo -e "${GREEN}Default SFTP Selected${NC}"
		rclone config create backupscript sftp
	fi

	#Set the RClone Settings in the config file
	rclone config update backupscript host $hostname #Set rclone config host
	rclone config update backupscript url $hostname #set rclone config url
	rclone config update backupscript user $username #set rclone config username
	rclone config password backupscript pass $password #set rclone config password
	rclone config update backupscript vendor other #set rclone config vendor
	if [ "$protocol" == "2" ]; then 
		rclone config update backupscript port $remoteport #set rclone config port
		rclone config password backupscript key_file_pass $password #set rclone key_file_pass password
		rclone config update backupscript use_insecure_cipher false #set rclone config use_insecure_cipher
	fi

	#Edit the backup.sh file
	sed -i "s|^localfolder=.*|localfolder=${localfolder}|g" /usr/local/backupscript/backup.sh #local folder
	sed -i "s|^tempfolder=.*|tempfolder=${tempfolder}|g" /usr/local/backupscript/backup.sh #temp folder
	sed -i "s|^remotefolder=.*|remotefolder=${remotefolder}|g" /usr/local/backupscript/backup.sh #remote folder
	sed -i "s|^usezip=.*|usezip=${usezip_value}|g" /usr/local/backupscript/backup.sh #usezip
	sed -i "s|^checksum=.*|checksum=${usechecksum_value}|g" /usr/local/backupscript/backup.sh #checksum
	sed -i "s|^retention=.*|retention=${retention_value}|g" /usr/local/backupscript/backup.sh #retention
	sed -i "s|^retention_daystostore=.*|retention_daystostore=${retention_daystostore}|g" /usr/local/backupscript/backup.sh #retention

	sed -i "s|^report_errors=.*|report_errors=${use_notifications}|g" /usr/local/backupscript/backup.sh #Turn on notifications

	sed -i "s|^discord_slack_notifications=.*|discord_slack_notifications=${use_discordnotifications}|g" /usr/local/backupscript/backup.sh #Turn on discord/slack notifications
	sed -i "s|^discord_slack_webhook=.*|discord_slack_webhook=${notifications_discordwebhook}|g" /usr/local/backupscript/backup.sh #discordwebhook

	if [ "$cronjob_install" == "true" ]; then
		touch /etc/cron.d/backupscript
		echo "0 $(( RANDOM % 24 )) * * * root bash /usr/local/backupscript/backup.sh" > /etc/cron.d/backupscript
		systemctl restart crond
	fi
fi
clear

#Echo the user how to test the backup
echo -e "${GREEN}The backup-script is installed use the following command to run the script ${YELLOW}bash /usr/local/backupscript/backup.sh${NC}"
if [ "retention_value" == "true" ]; then echo -e "${GREEN}The backupscript will run every day at ${YELLOW}03:00 am${NC}"; fi

exit 0
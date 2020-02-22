#!/bin/sh

# Project: Rclone backup script
# Author : houtknots
# Website: https://houtknots.nl/
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

#Check if the user is root or runs the script with sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Please run the script as root ${NC}- Try to run with sudo or as root user"
   exit 1
fi

function_installpackages () {
	#Install required packages
	$PKGINSTALLER install zip -y
	$PKGINSTALLER install unzip -y
	$PKGINSTALLER install curl -y
	curl https://rclone.org/install.sh | sudo bash

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
}

function_createfolders () {
	#Check if needed folders exist and create them if they do not exist
	if [ ! -d "/etc/backup" ]; then
        	echo -e "${YELLOW}Creating Backup folder...${NC}"
		mkdir /etc/backup
	fi
	if [ ! -d "/etc/backup/backupscript" ]; then
        	echo -e "${YELLOW}Creating SFTP folder...${NC}"
        	mkdir /etc/backup/backupscript
	fi
	if [ ! -d "/etc/backup/backupscript/temp" ]; then
		echo -e "${YELLOW}Creating Temp folder...${NC}"
		mkdir /etc/backup/backupscript/temp
	fi
	sleep 1
	clear
}

function_downloadbackupscript () {
	#Download backupscript from github
	if [ ! -f "/etc/backup/backupscript/backup.sh" ]; then
		curl https://raw.githubusercontent.com/houtknots/backupscript-rclone/master/backup.sh -o /etc/backup/backupscript/backup.sh
	fi
}

#ask if the user wants to purge the old config, otherwise abort script
function_newconfig () {
	while [ "$newconfig_continue" != "true" ]; do
		echo -e "${YELLOW}Would you like to continue, this will remove your current rclone config!?${NC}"
		read -p '[OVERWRITE CONFIG] (y/n): ' newconfig
			case $newconfig in
  			y|Y) 
				newconfig_continue="true"
				rclone config delete backupscript
			;;
	  		n|N)
				echo "Please use the commands to edit the rclone config"
				newconfig_continue="true"
				exit 0
			;;
  			*) 	
				echo "Please enter y or n"
				newconfig_continue="false"
			;;  
			esac
	done
	clear
}

function_protocol () {
	#Ask the user which protocol he or she wants to use for the file transfer
	echo -e "${YELLOW}Please select the protocol you would like to use.?${NC}"
	echo -e " [1] - WebDav"
	echo -e " [2] - SFTP"
	echo -e " [3] - FTP"
	echo -e " "
	read -e -p '[PROTOCOL]: ' -i "$protocol" protocol
	clear
}

function_hostname () {
	#Ask for the hostname
	echo -e "${YELLOW}Please enter your ${CYAN}remote hostname or IP ${YELLOW}and press enter${NC}"
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
		read -e -p '[LOCAL TEMPORARY FOLDER]: ' -i "/etc/backup/backupscript/temp" tempfolder
	clear
}

function_remotefolder () {
	#Ask where to put the files on the remote side
	echo -e "${YELLOW}Please enter the ${CYAN}remote folder${NC} ${YELLOW}you want to put the backup${NC}"
		read -e -p '[REMOTE FOLDER]: ' -i "/backupscript/" remotefolder
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
	function_protocol
	function_hostname
	function_username
	function_password
	function_localfolder
	function_localtempfolder
	function_remotefolder
	function_retention
	function_cronjob
}

#Ask if the user wants to create a new config
function_preparesystem () {
	function_installpackages
	function_createfolders
	function_downloadbackupscript
	function_newconfig
}

#Start the settings function
function_preparesystem
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
	echo -e "[RETENTION]: $retention_value"
	if [ "retention_value" == "true" ]; then
		echo -e "[RETENTION DAYS TO KEEP]: $retention_daystostore"
	fi
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
			echo -e "Please revisit your settings"
			2
			function_settings
		;;
  		*) 
			confirm_settings_continue="false"
			confirm_settings_install="false"
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

	#Edit the backup.sh file
	sed -i "s|^localfolder=.*|localfolder=${localfolder}|g" /etc/backup/backupscript/backup.sh #local folder
	sed -i "s|^tempfolder=.*|tempfolder=${tempfolder}|g" /etc/backup/backupscript/backup.sh #temp folder
	sed -i "s|^remotefolder=.*|remotefolder=${remotefolder}|g" /etc/backup/backupscript/backup.sh #remote folder
	sed -i "s|^retention=.*|retention=${retention_value}|g" /etc/backup/backupscript/backup.sh #retention
	sed -i "s|^retention_daystostore=.*|retention_daystostore=${retention_daystostore}|g" /etc/backup/backupscript/backup.sh #retention

	if [ "$cronjob_install" == "true" ]; then
		touch /etc/cron.d/backupscript
		echo "0 3 * * * root bash /etc/backup/backupscript/backup.sh" >> /etc/cron.d/backupscript
		systemctl restart crond
	fi
fi
clear


#########################################################
#              Notify User Install Is Done              #
#########################################################


#Echo the user how to test the backup
echo -e "${GREEN}The backup-script is installed use the following command to run the script ${YELLOW}bash /etc/backup/backupscript/backup.sh${NC}"

exit 0
#!/bin/sh

# Project: Rclone backup script
# Author : houtknots
# Website: https://houtknots.nl/
# Github : https://github.com/houtknots/Backupscript/

##########################################################
##########################################################
##########################################################

#Define color codes
RED='\033[1;31m'				#Color Red in echo
GREEN='\033[1;32m'				#Color GREEN in echo
CYAN='\e[36m'					#Color CYAN in echo
YELLOW='\e[33m'					#Color YELLOW in echo
NC='\033[0m'					#Remove Colors in echo

#Check the date
DATE=$(date +"%Y-%m-%d_%H-%M-%S")

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

#Check if the user is root or runs the script with sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Please run this script as root ${NC}- Try to run with sudo or as root user" 				
   exit 1
fi

#Install required packages
$PKGINSTALLER install zip -y
$PKGINSTALLER install curl -y
curl https://rclone.org/install.sh | sudo bash

sleep 1

#Check if Backup Folder exists if not create it
if [ ! -d "/etc/backup" ]; then																												
        echo -e "${YELLOW}Creating Backup folder...${NC}"
	mkdir /etc/backup
fi
#Check if SFTP Folder exists if not create it
if [ ! -d "/etc/backup/backupscript" ]; then																										
        echo -e "${YELLOW}Creating SFTP folder...${NC}"
        mkdir /etc/backup/backupscript
fi
#Check if temp folder exists if not create it
if [ ! -d "/etc/backup/backupscript/temp" ]; then																									
	echo -e "${YELLOW}Creating Temp folder...${NC}"
	mkdir /etc/backup/backupscript/temp
fi

#Ask the user which protocol he or she wants to use for the file transfer
echo -e "${YELLOW}Please select the protocol you would like to use.?${NC}"
echo -e " [1] - WebDav"
echo -e " [2] - SFTP"
echo -e " [3] - FTP"
echo -e " "
read -p '[PROTOCOL]: ' protocol
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


#Ask for the hostname
echo -e "${YELLOW}Please enter your ${CYAN}remote hostname or IP ${YELLOW}and press enter${NC}"
	read -p '[HOSTNAME]: ' hostname
	rclone config update backupscript host $hostname
	rclone config update backupscript url $hostname

#Ask for the SFTP User
echo -e "${YELLOW}Please enter your ${CYAN}remote user ${YELLOW}and press enter${NC}"	
	read -p '[USERNAME]: ' username
	rclone config update backupscript user $username

#Ask for the SFTP Password
echo -e "${YELLOW}Please enter your ${CYAN}remote password${NC} ${YELLOW}and press enter${NC}"		
	read -sp '[PASSWORD]: ' password
	rclone config password backupscript pass $password

#Update vendor to other, this option is not important for this script
rclone config update backupscript vendor other

#Ask which files to backup
echo -e "${YELLOW}Please enter the ${CYAN}local file location${NC} ${YELLOW}you want to backup and press enter${NC}"
	read -p '[LOCAL FOLDER]: ' localfolder
	if [ $localfolder == NULL ]; then 
		localfolder = /home/
	fi
	sed -i "s|^localfolder=.*|localfolder=${localfolder}|g" /etc/backup/backupscript/backup.sh
	
#Ask which files to backup
echo -e "${YELLOW}Please enter the ${CYAN}remote folder${NC} ${YELLOW}you want to put the backup${NC}"
	read -p '[REMOTE FOLDER]: ' remotefolder
	if [ $remotefolder == NULL ]; then 
		remotefolder = /
	fi
	sed -i "s|^remotefolder=.*|remotefolder=${remotefolder}|g" /etc/backup/backupscript/backup.sh

#Echo the user how to test the backup
echo -e "${GREEN}The backup-script is installed use the following command to run the script ${YELLOW}bash /etc/backup/backupscript/backup.sh${NC}"

exit 0
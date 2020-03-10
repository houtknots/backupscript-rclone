#!/bin/sh

# Project: Rclone backup script
# Author : houtknots
# Website: https://houtknots.nl/
# Github : https://github.com/houtknots

##########################################################
#					   Start Script				         #
##########################################################

localfolder=/home/
remotefolder=/backupscript/
currentdate=$(date +"%Y-%m-%d_%H-%M-%S")
tempfolder="/etc/backup/backupscript/temp"
tempfile="$tempfolder/$currentdate.zip"
usezip="false"
retention="false"
retention_daystostore="14"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Please run the script as root ${NC}- Try to run with sudo or as root user"
   exit 1
fi

#If -f value is provided skip the countdown
if  [[ $1 = "-f" ]]; then
	skiptimer="true"
else
	skiptimer="false"
fi

function_timer () {
	#Countdown timer before starting backup
	if [ "$skiptimer" == "false" ]; then
		secs=$((10))
		while [ $secs -gt 0 ]; do
			echo -ne -e "${GREEN}Backup starts in ${RED}$secs ${GREEN}seconds${NC} - ${GREEN}Press ${RED}Control+C ${GREEN}to cancel\033[0K\r ${NC}"
			sleep 1
			: $((secs--))
		done
	fi
	clear
}

function_clearlog () {
	#Clear Log Files
	echo " " > /etc/backup/backupscript/backup.log
}

function_createfolder () {
	#Check if temp folder exists if not create it
	if [ ! -d "$tempfolder" ]; then	
		echo -e "${YELLOW}Creating Temp folder...${NC}"
		mkdir $tempfolder
		sleep 1
	fi
}

function_zipfiles () {
	if [ "$usezip" == "true" ]; then
		zip -r $tempfile $localfolder
	fi
}

function_upload () {
	#Backup the files to a remote location
	if [ "$usezip" == "true" ]; then
		rclone copy $tempfile backupscript:$remotefolder --progress -q --log-file=/etc/backup/backupscript/backup.log
	else
		rclone copy $localfolder backupscript:$remotefolder/$currentdate/ --progress -q --log-file=/etc/backup/backupscript/backup.log
	fi
}

function_deltempfiles () {
#Delete temp files when done
	if [ "$usezip" == "true" ];
	then
		if [ -f "$tempfile" ];
		then
			rm -rf $tempfile
			if [ -f "$tempfile" ];
			then
				echo -e "${RED}Cleanup failed${NC} - Start the script again with ${YELLOW}-c ${NC}To restart the cleanup proccess"
				echo -e "${RED}Cleanup failed${NC} - Start the script again with ${YELLOW}-c ${NC}To restart the cleanup proccess" > /etc/backup/backupscript/backup.log
				exit 1
			else
				echo -e "${GREEN}Cleanup Succesfull${NC}"
			fi
		else
			echo -e "${RED}No File found or we had insufficient permissions${NC} - Run the script again with ${YELLOW}-c ${NC}To restart the cleanup proccess"
			echo -e "${RED}No File found or we had insufficient permissions${NC} - Run the script again with ${YELLOW}-c ${NC}To restart the cleanup proccess" > /etc/backup/backupscript/backup.log
		fi
	fi
}

function_retention () {
	rclone delete backupscript:$remotefolder --min-age $retention_daystostore\d --progress -q --log-file=/etc/backup/backupscript/retention.log
}

#########################################################
#                Start the backupscript                 #
#########################################################


function_timer
function_clearlog
function_createfolder
function_zipfiles

function_upload
function_deltempfiles

if [ "$retention" == "true" ]; then
	function_retention
fi

exit 0
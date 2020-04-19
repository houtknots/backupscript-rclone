#!/bin/bash

# Project: Rclone backup script
# Author : houtknots
# Website: https://houtknots.nl/
# Github : https://github.com/houtknots

##########################################################
# 					     Settings			             #
##########################################################

#Folder settings
localfolder=/home/
remotefolder=/backupscript/
currentdate=$(date +"%Y-%m-%d_%H-%M-%S")
tempfolder="/etc/backup/backupscript/temp"
tempfile="$tempfolder/$currentdate.zip"
hostname="`hostname`"

#Notifications
discord_slack_webhook=""
report_errors=false
discord_slack_notifications=false

#Retention
retention_daystostore="14"
retention=false

#Zip
usezip=false

#Filecheck
checksum=false

##########################################################
# 					     Script				             #
##########################################################

#Check if the script runs as root or with sudo
if [[ $EUID -ne 0 ]];
then
   echo -e "${RED}Please run the script as root ${NC}- Try to run with sudo or as root user"
   exit 1
fi

#If -f value is provided skip the countdown
if  [[ $1 = "-f" ]];
then
	skiptimer="true"
else
	skiptimer="false"
fi

function_start_countdowntimer () {
	#Countdown timer before starting backup
	if [ "$skiptimer" == "false" ];
	then
		secs=$((10))
		while [ $secs -gt 0 ];
		do
			echo -ne -e "${GREEN}Backup starts in ${RED}$secs ${GREEN}seconds${NC} - ${GREEN}Press ${RED}Control+C ${GREEN}to cancel\033[0K\r ${NC}"
			sleep 1
			: $((secs--))
		done
	fi
	clear
}

function_clearlog () {
	#Clear Log Files
	true > /etc/backup/backupscript/backup.log
}

function_createfolder () {
	#Check if temp folder exists if not create it
	if [ ! -d "$tempfolder" ];
	then	
		echo -e "${YELLOW}Creating Temp folder...${NC}"
		mkdir $tempfolder
		sleep 1
	fi
}

function_zipfiles () {
	if [ "$usezip" == "true" ];
	then
		zip -r $tempfile $localfolder
	fi
}

function_upload () {
	#Backup the files to a remote location
	if [ "$usezip" == "true" ];
	then
		rclone copy $tempfile backupscript:$remotefolder --progress -q --log-file=/etc/backup/backupscript/backup.log
	else
		rclone copy $localfolder backupscript:$remotefolder/$currentdate/ --progress -q --log-file=/etc/backup/backupscript/backup.log
	fi
}

function_checksum () {
	#Check the files from the remote folder are the the same as the local ones
	if [ "$checksum" == "true" ]; 
	then
		if [ "$usezip" == "true" ];
		then
			rclone check $tempfile backupscript:$remotefolder -q --log-file=/etc/backup/backupscript/backup.log
		else
			rclone check $localfolder backupscript:$remotefolder/$currentdate/ -q --log-file=/etc/backup/backupscript/backup.log
		fi
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
				echo -e "${RED}Cleanup failed${NC} - Start the script again with ${YELLOW}-c ${NC}To restart the cleanup proccess" >> /etc/backup/backupscript/backup.log
				exit 1
			else
				echo -e "${GREEN}Cleanup Succesfull${NC}"
			fi
		else
			echo -e "${RED}No File found or we had insufficient permissions${NC} - Run the script again with ${YELLOW}-c ${NC}To restart the cleanup proccess"
			echo -e "${RED}No File found or we had insufficient permissions${NC} - Run the script again with ${YELLOW}-c ${NC}To restart the cleanup proccess" >> /etc/backup/backupscript/backup.log
		fi
	fi
}

function_retention () {
	if [ "$retention" == "true" ]; 
	then
		rclone delete backupscript:$remotefolder --min-age $retention_daystostore\d --progress -q --log-file=/etc/backup/backupscript/backup.log
	else
		echo -e "Retention function has not been enabled, skipping the retention process"
	fi
}

function_starttimer () {
	#Start the timer
	Timer="$(date +%s)"
}

function_stoptimer () {
	#Stop the timer
	Timer="$(($(date +%s)-T))"
	TimeElapsed="$(($Timer / 3600))hrs $((($Timer / 60) % 60))min $(($Timer % 60))sec"
	echo "The backup has finished it took $TimeElapsed"
}

function_report_errors () {
	#Check if the report errors function is true
	if [ "$report_errors" == "true" ];
	then
		if [ "$discord_slack_notifications" == "true" ];
		then
			#Check if the backupscript logs are empty
			if [ -s "/etc/backup/backupscript/backup.log" ]
			then
				curl -H "Content-Type: application/json" -X POST -d "{\"username\":\"Backupscript\", \"embeds\":[{\"title\":\"$hostname\",\"description\":\"The backup of $currentdate failed it took $TimeElapsed\",\"color\":16711680}]}" $discord_slack_webhook
			else
				curl -H "Content-Type: application/json" -X POST -d "{\"username\":\"Backupscript\", \"embeds\":[{\"title\":\"$hostname\",\"description\":\"The backup of $currentdate finished successfully it took $TimeElapsed\",\"color\":655104}]}" $discord_slack_webhook
			fi
		fi
	fi
}

function_historylog () {
	if [ -s "/etc/backup/backupscript/history.log" ]
	then
		echo [FAILED] - $currentdate - Please check the backup.log file to see the errors >> /etc/backup/backupscript/history.log
	else
		echo [FINISHED] - $currentdate >> /etc/backup/backupscript/history.log
	fi
}
#########################################################
#                     Start Backups			            #
#########################################################


function_start_countdowntimer
function_starttimer
function_clearlog
function_createfolder
function_zipfiles

function_upload
function_checksum
function_deltempfiles
function_retention

function_stoptimer
function_report_errors
function_historylog

exit 0
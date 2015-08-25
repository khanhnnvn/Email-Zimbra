#!/bin/bash
# Usage: ZimBackup.sh full	- For full backup (Cold)
#	 ZimBackup.sh diff	- For diffrential backup (Cold)
#	 ZimBackup.sh msgfull	- For complete message backup (Hot)
#	 ZimBackup.sh msgdiff	- For diffrential message backup (Hot)
#
# When you run this script via crontab be sure to add '> /dev/null 2>&1' at the end
# of the script like below or the tar command will fail for no apparent reason.
# 00 12 * * * ZimBackup.sh full > /dev/null 2>&1
#


#### Global Settings ####
ZimInstPath=/opt			# Installation path for Zimbra, exluding the zimbra folder.
ZimHome=zimbra				# The Zimbra installation folder, exluding path to folder.
ZimBackupPath=/opt/backup		# Backup folder where backup files should be placed.
ZimTempPath=/opt/backup/tmp		# Temporary backup folder, should be placed as a subfolder to backup folder.

#### Log Settings ####
ZimLogEnable=no				# Turns logging off or on.
ZimLogFileName=BackupZimbra.log		# Log filename
ZimLogVerbose=no			# Activates extra logging information 

#### File Transfer Settings ####

# Enable Services (yes/no)
ZimFtpEnable=no				# Enable/Disable ftp file transfer.
ZimScpEnable=no				# Enable/Disable scp file transfer.

# Extra FTP Settings
ZimFtpOpt=''				# Extra options for ftp file transfer, see manual for ftp command

# Extra SCP Settings
ZimScpOpt=''				# Extra options for ftp file transfer, see manual for scp command

# Common Settings
ZimFilehostUser=			# Username for file transfers
ZimFilehostPass=			# Password for file transfers
ZimFilehostAddress=			# Host address for file transfers
ZimFilehostFolder=			# Folder on host where files will be placed during file transfer

#### File Delete Settings ####
ZimDeleteLocalFile=no			# Enable/Disable backup file deletion efter sucessfull backup.
ZimDeleteTimeSet=0			# Set in minutes above 0 to keep a desired amount of files locally,
					# be sure to match the time with your backup schedules.

##### Do not change anything below this line unless you know what you are doing #####

# Fetch backup type 
ZimBackupType=$1

# Set filename for backup files
ZimFilenameSystemFull=ZimBackupSystemFull_`date +%Y_%m_%d_%H%M`.tar.gz
ZimFilenameSystemDiff=ZimBackupSystemDiff_`date +%Y_%m_%d_%H%M`.tar.gz
ZimFilenameMsgFull=ZimBackupMsgFull_`date +%Y_%m_%d_%H%M`.tar.gz
ZimFilenameMsgDiff=ZimBackupMsgDiff_`date +%Y_%m_%d_%H%M`.tar.gz

pre_check() {
# Check if expect is installed and file transfer is enabled, stops script if not
if [ $ZimFtpEnable = 'yes' ] || [ $ZimScpEnable = 'yes' ]
then
 if [ ! -e /usr/bin/expect ]
  then
   echo "expect command is missing, this is required for file transfer options, script exiting..."
   exit
 fi
fi

# Create log file if not exist
if [ $ZimLogEnable = 'yes' ]
 then
  touch $ZimBackupPath/$ZimLogFileName
fi

# Check to see if the tmp folder exist, and create if not
mkdir -p $ZimTempPath

# Check which zimbra version that is installed, for recovery purpose 
sudo -u zimbra $ZimInstPath/$ZimHome/bin/zmcontrol -v > $ZimTempPath/zimbra_version.txt
}

full_backup() {
if [ $ZimLogEnable = 'yes' ] && [ $ZimLogVerbose = 'yes' ]
 then
   # Removing possible old zimbra backup folder
   echo "`date +%Y_%m_%d_%H%M%S` - Removing old backup folder from $ZimTempPath..." >> $ZimBackupPath/$ZimLogFileName
   rm -r -f $ZimTempPath/$ZimHome >> $ZimBackupPath/$ZimLogFileName
   echo "`date +%Y_%m_%d_%H%M%S` - Removing old backup folder from $ZimTempPath done" >> $ZimBackupPath/$ZimLogFileName

   # Stopping Zimbra
   echo "`date +%Y_%m_%d_%H%M%S` - Zimbra services stopping..." >> $ZimBackupPath/$ZimLogFileName
   /etc/init.d/zimbra stop >> $ZimBackupPath/$ZimLogFileName
   sleep 20
   echo "`date +%Y_%m_%d_%H%M%S` - Zimbra services stopped." >> $ZimBackupPath/$ZimLogFileName

   # Backing up zimbra folder
   echo "`date +%Y_%m_%d_%H%M%S` - Zimbra folder copying to backup..." >> $ZimBackupPath/$ZimLogFileName
   cp -rv $ZimInstPath/$ZimHome $ZimTempPath/ >> $ZimBackupPath/$ZimLogFileName
   echo "`date +%Y_%m_%d_%H%M%S` - Zimbra folder copied to backup." >> $ZimBackupPath/$ZimLogFileName

   # Starting Zimbra
   echo "`date +%Y_%m_%d_%H%M%S` - Zimbra services starting..." >> $ZimBackupPath/$ZimLogFileName
   /etc/init.d/zimbra start >> $ZimBackupPath/$ZimLogFileName
   echo "`date +%Y_%m_%d_%H%M%S` - Zimbra services started." >> $ZimBackupPath/$ZimLogFileName

   # Compressing backup for space reduction
   echo "`date +%Y_%m_%d_%H%M%S` - Compressing backup folder..." >> $ZimBackupPath/$ZimLogFileName
   tar -zcvf $ZimBackupPath/$ZimFilenameSystemFull -C $ZimTempPath $ZimHome zimbra_version.txt >> $ZimBackupPath/$ZimLogFileName
   echo "`date +%Y_%m_%d_%H%M%S` - Compressed backup folder." >> $ZimBackupPath/$ZimLogFileName
 else
  # Removing possible old zimbra backup folder
  rm -r -f $ZimTempPath/$ZimHome
  # Stopping Zimbra
  /etc/init.d/zimbra stop
  sleep 20
  # Backing up zimbra folder
  cp -rv $ZimInstPath/$ZimHome $ZimTempPath/
  # Starting Zimbra
  /etc/init.d/zimbra start
  # Compressing backup for space reduction
  tar -zcvf $ZimBackupPath/$ZimFilenameSystemFull -C $ZimTempPath $ZimHome zimbra_version.txt
fi
}

diff_backup() {
if [ $ZimLogEnable = 'yes' ] && [ $ZimLogVerbose = 'yes' ]
 then
  # Hot sync before shutdown on zimbra folder
  echo "`date +%Y_%m_%d_%H%M%S` - Hot syncing to backup folder..." >> $ZimBackupPath/$ZimLogFileName
  rsync -avHK --delete $ZimInstPath/$ZimHome $ZimTempPath/ >> $ZimBackupPath/$ZimLogFileName
  echo "`date +%Y_%m_%d_%H%M%S` - Hot syncing to backup folder done." >> $ZimBackupPath/$ZimLogFileName

  # Stopping Zimbra
  echo "`date +%Y_%m_%d_%H%M%S` - Zimbra services stopping..." >> $ZimBackupPath/$ZimLogFileName
  /etc/init.d/zimbra stop >> $ZimBackupPath/$ZimLogFileName >> $ZimBackupPath/$ZimLogFileName
  sleep 20
  echo "`date +%Y_%m_%d_%H%M%S` - Zimbra services stopped." >> $ZimBackupPath/$ZimLogFileName

  # Cold sync of zimbra folder
  echo "`date +%Y_%m_%d_%H%M%S` - Cold syncing to backup folder..." >> $ZimBackupPath/$ZimLogFileName
  rsync -avHK --delete $ZimInstPath/$ZimHome $ZimTempPath/ >> $ZimBackupPath/$ZimLogFileName
  echo "`date +%Y_%m_%d_%H%M%S` - Cold syncing to backup folder done." >> $ZimBackupPath/$ZimLogFileName

  # Starting Zimbra
  echo "`date +%Y_%m_%d_%H%M%S` - Zimbra services starting..." >> $ZimBackupPath/$ZimLogFileName
  /etc/init.d/zimbra start >> $ZimBackupPath/$ZimLogFileName
  echo "`date +%Y_%m_%d_%H%M%S` - Zimbra services started." >> $ZimBackupPath/$ZimLogFileName

  # Compressing backup for space reduction and removing unpacked folder
  echo "`date +%Y_%m_%d_%H%M%S` - Compressing backup folder..." >> $ZimBackupPath/$ZimLogFileName
  tar -zcvf $ZimBackupPath/$ZimFilenameSystemDiff -C $ZimTempPath $ZimHome zimbra_version.txt >> $ZimBackupPath/$ZimLogFileName
  echo "`date +%Y_%m_%d_%H%M%S` - Compressed backup folder." >> $ZimBackupPath/$ZimLogFileName
 else
  # Hot sync before shutdown on zimbra folder
  rsync -avHK --delete $ZimInstPath/$ZimHome $ZimTempPath/
  # Stopping Zimbra
  /etc/init.d/zimbra stop >> $ZimBackupPath/$ZimLogFileName
  sleep 20
  # Cold sync of zimbra folder
  rsync -avHK --delete $ZimInstPath/$ZimHome $ZimTempPath/
  # Starting Zimbra
  /etc/init.d/zimbra start >> $ZimBackupPath/$ZimLogFileName
  # Compressing backup for space reduction and removing unpacked folder
  tar -zcvf $ZimBackupPath/$ZimFilenameSystemDiff -C $ZimTempPath $ZimHome zimbra_version.txt
fi
}

msgfull_backup() {
if [ $ZimLogEnable = 'yes' ] && [ $ZimLogVerbose = 'yes' ]
 then
  # Removing possible old store backup folder
  echo "`date +%Y_%m_%d_%H%M%S` - Removing old backup folder from $ZimTempPath" >> $ZimBackupPath/$ZimLogFileName
  rm -r -f $ZimTempPath/store >> $ZimBackupPath/$ZimLogFileName
  echo "`date +%Y_%m_%d_%H%M%S` - Removing old backup folder from $ZimTempPath done" >> $ZimBackupPath/$ZimLogFileName

  # Make dir for hot sync
  echo "`date +%Y_%m_%d_%H%M%S` - Creating backup folder..." >> $ZimBackupPath/$ZimLogFileName
  mkdir -p $ZimTempPath/store >> $ZimBackupPath/$ZimLogFileName
  echo "`date +%Y_%m_%d_%H%M%S` - Creating backup folder done." >> $ZimBackupPath/$ZimLogFileName

  # Hot sync of mailbox messages
  echo "`date +%Y_%m_%d_%H%M%S` - Hot syncing to backup folder..." >> $ZimBackupPath/$ZimLogFileName
  rsync -avHK --delete $ZimInstPath/$ZimHome/store/0 $ZimTempPath/store/ >> $ZimBackupPath/$ZimLogFileName
  echo "`date +%Y_%m_%d_%H%M%S` - Hot syncing to backup folder done." >> $ZimBackupPath/$ZimLogFileName

  # Compressing store folder for space reduction
  echo "`date +%Y_%m_%d_%H%M%S` - Compressing backup folder..." >> $ZimBackupPath/$ZimLogFileName
  tar -zcvf $ZimBackupPath/$ZimFilenameMsgFull -C $ZimTempPath store zimbra_version.txt >> $ZimBackupPath/$ZimLogFileName
  echo "`date +%Y_%m_%d_%H%M%S` - Compressed backup folder." >> $ZimBackupPath/$ZimLogFileName
 else
  # Removing possible old store backup folder
  rm -r -f $ZimTempPath/store
  # Make dir for hot sync
  mkdir -p $ZimTempPath/store
  # Hot sync of mailbox messages
  rsync -avHK --delete $ZimInstPath/$ZimHome/store/0 $ZimTempPath/store/
  # Compressing store folder for space reduction
  tar -zcvf $ZimBackupPath/$ZimFilenameMsgFull -C $ZimTempPath store zimbra_version.txt
fi
}

msgdiff_backup() {
if [ $ZimLogEnable = 'yes' ] && [ $ZimLogVerbose = 'yes' ]
 then
  # Make dir for hot sync
  echo "`date +%Y_%m_%d_%H%M%S` - Creating backup folder..." >> $ZimBackupPath/$ZimLogFileName
  mkdir -p $ZimTempPath/store >> $ZimBackupPath/$ZimLogFileName
  echo "`date +%Y_%m_%d_%H%M%S` - Creating backup folder done." >> $ZimBackupPath/$ZimLogFileName

  # Hot sync of mailbox messages
  echo "`date +%Y_%m_%d_%H%M%S` - Hot syncing to backup folder..." >> $ZimBackupPath/$ZimLogFileName
  rsync -avHK --delete $ZimInstPath/$ZimHome/store/0 $ZimTempPath/store/ >> $ZimBackupPath/$ZimLogFileName
  echo "`date +%Y_%m_%d_%H%M%S` - Hot syncing to backup folder done." >> $ZimBackupPath/$ZimLogFileName

  # Compressing store folder for space reduction
  echo "`date +%Y_%m_%d_%H%M%S` - Compressing backup folder..." >> $ZimBackupPath/$ZimLogFileName
  tar -zcvf $ZimBackupPath/$ZimFilenameMsgDiff -C $ZimTempPath store zimbra_version.txt
  echo "`date +%Y_%m_%d_%H%M%S` - Compressed backup folder." >> $ZimBackupPath/$ZimLogFileName
 else
  # Make dir for hot sync
  mkdir -p $ZimTempPath/store
  # Hot sync of mailbox messages
  rsync -avHK --delete $ZimInstPath/$ZimHome/store/0 $ZimTempPath/store/
  # Compressing store folder for space reduction
  tar -zcvf $ZimBackupPath/$ZimFilenameMsgDiff -C $ZimTempPath store zimbra_version.txt
fi
}

file_transfer() {
# Check which filename to use in file transfer
if [ $ZimBackupType == "full" ]
then
 ZimFilenameTransfer=$ZimFilenameSystemFull
fi
if [ $ZimBackupType == "diff" ]
then
 ZimFilenameTransfer=$ZimFilenameSystemDiff
fi
if [ $ZimBackupType == "msgfull" ]
then
 ZimFilenameTransfer=$ZimFilenameMsgFull
fi
if [ $ZimBackupType == "msgdiff" ]
then
 ZimFilenameTransfer=$ZimFilenameMsgDiff
fi

# Transfer with ftp
if [ $ZimFtpEnable == "yes" ]
then
if [ $ZimLogEnable = 'yes' ] && [ $ZimLogVerbose = 'yes' ]
 then
  echo "`date +%Y_%m_%d_%H%M%S` - Sending file via ftp to offsite storage..." >> $ZimBackupPath/$ZimLogFileName
  # Make a temporary script for expect commands
  touch $ZimTempPath/ftp.exp
  # Fill script with commands
  echo '#!/usr/bin/expect --' >> $ZimTempPath/ftp.exp
  echo 'set timeout -1' >> $ZimTempPath/ftp.exp
  echo 'spawn ftp '$ZimFilehostAddress >> $ZimTempPath/ftp.exp
  echo 'expect ):' >> $ZimTempPath/ftp.exp
  echo 'send '$ZimFilehostUser'\r' >> $ZimTempPath/ftp.exp
  echo 'expect :' >> $ZimTempPath/ftp.exp
  echo 'send '$ZimFilehostPass'\r' >> $ZimTempPath/ftp.exp
  echo 'expect >' >> $ZimTempPath/ftp.exp
  echo 'send '$ZimFtpOpt'\r' >> $ZimTempPath/ftp.exp
  echo 'send "send '$ZimBackupPath/$ZimFilenameTransfer $ZimFilehostFolder/$ZimFilenameTransfer'\r"' >> $ZimTempPath/ftp.exp
  echo 'expect >' >> $ZimTempPath/ftp.exp
  echo 'send quit\r' >> $ZimTempPath/ftp.exp
  echo 'expect closed' >> $ZimTempPath/ftp.exp
  # Run expect with created script
  expect $ZimTempPath/ftp.exp  >> $ZimBackupPath/$ZimLogFileName
  # Delete temporary expect script
  rm $ZimTempPath/ftp.exp
  echo "`date +%Y_%m_%d_%H%M%S` - Sending file via ftp to offsite storage done." >> $ZimBackupPath/$ZimLogFileName
 else
  # Make a temporary script for expect commands
  touch $ZimTempPath/ftp.exp
  # Fill script with commands
  echo '#!/usr/bin/expect --' >> $ZimTempPath/ftp.exp
  echo 'set timeout -1' >> $ZimTempPath/ftp.exp
  echo 'spawn ftp '$ZimFilehostAddress >> $ZimTempPath/ftp.exp
  echo 'expect ):' >> $ZimTempPath/ftp.exp
  echo 'send '$ZimFilehostUser'\r' >> $ZimTempPath/ftp.exp
  echo 'expect :' >> $ZimTempPath/ftp.exp
  echo 'send '$ZimFilehostPass'\r' >> $ZimTempPath/ftp.exp
  echo 'expect >' >> $ZimTempPath/ftp.exp
  echo 'send '$ZimFtpOpt'\r' >> $ZimTempPath/ftp.exp
  echo 'send "send '$ZimBackupPath/$ZimFilenameTransfer $ZimFilehostFolder/$ZimFilenameTransfer'\r"' >> $ZimTempPath/ftp.exp
  echo 'expect >' >> $ZimTempPath/ftp.exp
  echo 'send quit\r' >> $ZimTempPath/ftp.exp
  echo 'expect closed' >> $ZimTempPath/ftp.exp
  # Run expect with created script
  expect $ZimTempPath/ftp.exp
  # Delete temporary expect script
  rm $ZimTempPath/ftp.exp
fi

fi
# Transfer with scp
if [ $ZimScpEnable == "yes" ]
then
 if [ $ZimLogEnable = 'yes' ] && [ $ZimLogVerbose = 'yes' ]
  then
   echo "`date +%Y_%m_%d_%H%M%S` - Sending file via scp to offsite storage..." >> $ZimBackupPath/$ZimLogFileName
   # Make a temporary script for expect commands
   touch $ZimTempPath/scp.exp
   # Fill script with commands
   echo '#!/usr/bin/expect --' >> $ZimTempPath/scp.exp
   echo 'set timeout -1' >> $ZimTempPath/scp.exp
   echo 'spawn scp '$ZimScpOpt $ZimBackupPath/$ZimFilenameTransfer $ZimFilehostUser'@'$ZimFilehostAddress':'$ZimFilehostFolder >> $ZimTempPath/scp.exp
   echo 'expect :' >> $ZimTempPath/scp.exp
   echo 'send '$ZimFilehostPass'\r' >> $ZimTempPath/scp.exp
   echo 'expect closed' >> $ZimTempPath/scp.exp
   # Run expect with created script
   expect $ZimTempPath/scp.exp  >> $ZimBackupPath/$ZimLogFileName
   # Delete temporary expect script
   rm $ZimTempPath/scp.exp
   echo "`date +%Y_%m_%d_%H%M%S` - Sending file via scp to offsite storage done." >> $ZimBackupPath/$ZimLogFileName
  else
   # Make a temporary script for expect commands
   touch $ZimTempPath/scp.exp
   # Fill script with commands
   echo '#!/usr/bin/expect --' >> $ZimTempPath/scp.exp
   echo 'set timeout -1' >> $ZimTempPath/scp.exp
   echo 'spawn scp '$ZimScpOpt $ZimBackupPath/$ZimFilenameTransfer $ZimFilehostUser'@'$ZimFilehostAddress':'$ZimFilehostFolder >> $ZimTempPath/scp.exp
   echo 'expect :' >> $ZimTempPath/scp.exp
   echo 'send '$ZimFilehostPass'\r' >> $ZimTempPath/scp.exp
   echo 'expect closed' >> $ZimTempPath/scp.exp
   # Run expect with created script
   expect $ZimTempPath/scp.exp
   # Delete temporary expect script
   rm $ZimTempPath/scp.exp
 fi
fi

# Remove local file(s) if ZimDeleteLocalFile is set to 'yes'
if [ $ZimDeleteLocalFile == "yes" ]
then
 if [ $ZimLogEnable = 'yes' ] && [ $ZimLogVerbose = 'yes' ]
  then
   echo "`date +%Y_%m_%d_%H%M%S` - Deleting local file(s)..." >> $ZimBackupPath/$ZimLogFileName
   find $ZimBackupPath -maxdepth 1 -type f -mmin +$ZimDeleteTimeSet -name ZimBackup\*.tar.gz -exec rm {} +  >> $ZimBackupPath/$ZimLogFileName
   echo "`date +%Y_%m_%d_%H%M%S` - Deleting local file(s) done." >> $ZimBackupPath/$ZimLogFileName
  else
   find $ZimBackupPath -maxdepth 1 -type f -mmin +$ZimDeleteTimeSet -name ZimBackup\*.tar.gz -exec rm {} +
 fi
fi
}

log_start() {
if [ $ZimLogEnable = 'yes' ]
 then
  echo "" >> $ZimBackupPath/$ZimLogFileName
  echo "-------------------------------------------------------" >> $ZimBackupPath/$ZimLogFileName
  echo "Backup Started: `date +%Y_%m_%d_%H%M%S` Type: $ZimBackupType" >> $ZimBackupPath/$ZimLogFileName
fi
}

log_end() {
if [ $ZimLogEnable = 'yes' ]
 then
  echo "Backup Finished: `date +%Y_%m_%d_%H%M%S` Type: $ZimBackupType" >> $ZimBackupPath/$ZimLogFileName
  echo "-------------------------------------------------------" >> $ZimBackupPath/$ZimLogFileName
fi
}

case $1 in
full)
pre_check
log_start
full_backup
file_transfer
log_end
;;
diff)
pre_check
log_start
diff_backup
file_transfer
log_end
;;
msgfull)
pre_check
log_start
msgfull_backup
file_transfer
log_end
;;
msgdiff)
pre_check
log_start
msgdiff_backup
file_transfer
log_end
;;
*)
echo "Usage: ZimColdBackup.sh {full|diff|msgfull|msgdiff}"
;;
esac

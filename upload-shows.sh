#!/bin/bash

##################################################################################
################################### PLEXiDRIVE ###################################
################################ TV SHOWS UPLOADS ################################
##################################################################################

# Directory where this file exists
plexidrive_dir=`dirname $(realpath -s $0)`
cd "$plexidrive_dir"

# Read in configuration file
if [ -e ./plexidrive.conf ] ; then
	source ./plexidrive.conf
else
	echo "Configuration file - plexidrive.conf - not found."
	echo "$(date +%F_%T) Configuration file - plexidrive.conf - not found." >> "$plexidrive_dir/upload-error"
	exit 1
fi

# Loop through to see if any files need uploading
IFS=$'\n';
for f in $(find "$local_tvshow_path" -regextype posix-egrep -regex ".*\.($file_types)$"); do

	# Set up variables and directory
	path=${f%/*}
	cd "$path"
	show=`echo ${path#$local_tvshow_path} | cut -d'/' -f1`
	season=`echo ${path#$local_tvshow_path} | cut -d'/' -f2`
	f=${f##*/}
	echo "File: $f"

	# Upload file to each Google drive account
	for (( i=0; i<${num_of_gdrives}; i++ ));
	do
		echo "Starting upload to ${drive_names[i]}..."
		if [ -z "$rclone_config" ]
		then
			rclone copy "$f" "${drive_names[i]}":/TV\ Shows/"$show"/"$season"/ &
		else
			rclone --config "$rclone_config" copy "$f" "${drive_names[i]}":/TV\ Shows/"$show"/"$season"/ &
		fi
	done

	# Wait until all uploads have finished before continuing
	FAIL=0
	for job in `jobs -p`
	do
		wait $job || let "FAIL+=1"
	done

	# Check exit code of upload to make sure no errors occurred
	if [ "$FAIL" != "0" ] ; then
		echo "Upload failed. ($FAIL)"
		echo "$(date +%F_%T) Upload of $f failed - $FAIL." >> "$plexidrive_dir/upload-error"
		exit 1
	fi
	
	echo "Done upload."

	# Add season folder to list of directories for plex to scan
	desc="$show:$season:"
	check=`cat $plexidrive_dir/plex-scan | grep $desc`
	if [ -z "$check" ]
	then
		echo "tv:$desc" >> "$plexidrive_dir/plex-scan"
	fi

	# Delete local file after successful upload, if enabled
	if [ "$delete_after_upload" = true ] ; then
		# Delete the local file
		rm "$f"
	fi
done

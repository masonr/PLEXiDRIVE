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
		echo "Uploading to ${drive_names[i]}"
		rclone copy "$f" "${drive_names[i]}":/TV\ Shows/"$show"/"$season"/
	done

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

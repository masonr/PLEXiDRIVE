#!/bin/bash

###################################################################################
################################### PLEXiDRIVE ####################################
################################## MOVIE UPLOADS ##################################
###################################################################################

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

# Loop through to see if any files are done downloading
IFS=$'\n';
for f in $(find "$local_movies_path" -regextype posix-egrep -regex ".*\.($file_types)$"); do

	# Set up variables and folder
	path=${f%/*}
	cd "$path"
	f=${f##*/}
	folder=`echo ${path#$local_movies_path} | cut -d'/' -f1`
	in_root=false
	if [ -z "$folder" ]
	then
		in_root=true # Denote movie is in the movie root folder
		folder=${f%.*} # Make the folder name the name of the movie (minus the file extension)
	fi
	echo "File: $f"

	# Upload file to every Google drive account
	for (( i=0; i<${num_of_gdrives}; i++ ));
	do
		echo "Starting upload to ${drive_names[i]}..."
		rclone copy "$f" "${drive_names[i]}":/Movies/"$folder"/ &		
	done

	# Wait until all uploads have finished before continuing
	FAIL=0
	for job in `jobs -p`
	do
		wait $job || let "FAIL+=1"
	done

	echo "Done upload."

	# Add movie's folder to list of directories for plex to scan
	echo "mov:$folder" >> "$plexidrive_dir/plex-scan"

	# Delete local file after successful upload, if enabled
	if [ "$delete_after_upload" = true ] ; then
		# Delete the local folder
		if [ "$in_root" = "true" ]
		then
			rm $f # delete file if in local movie directory
		else
			rm -rf $path # delete movie folder
		fi	
	fi
done

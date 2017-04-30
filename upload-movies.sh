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
	if [ "$folder" = "$f" ]
	then
		in_root=true # Denote movie is in the movie root folder
		folder=${folder%.*} # Make the folder name the name of the movie (minus the file extension)
	fi
	echo "File: $f"

	# Upload file to every Google drive account
	for (( i=0; i<${num_of_gdrives}; i++ ));
	do
		wait_time=1

		while true
		do
			mov_root=`cat $plexidrive_dir/gdrive-directory | grep "${drive_names[i]}:MOVIE_ROOT::"`
			# Create the movie folder within the Movies directory on drive
			out=`gdrive --config ${gdrive_config_paths[i]} mkdir --parent ${mov_root##*::} "$folder"`
			mov_folder=`echo $out | head -n1 | awk '{print $2;}'`
		
			if [[ $out == *"Error"* ]] && [[ $out == *"rateLimitExceeded"* ]]
			then
				wait_time=$((wait_time * 2))
				echo "Rate Limit Exceeded, waiting $wait_time seconds."
				echo "$(date +%F_%T) RateLimitExceeded mov:${drive_names[i]}:$folder:$out" >> "$plexidrive_dir/upload-error"
				sleep $wait_time
			elif [[ $out =~ "Error \d{3}" ]] && [[ $out != *"rateLimitExceeded"* ]]
			then
				echo "$(date +%F_%T) UnknownError mov:${drive_names[i]}:$folder:$out" >> "$plexidrive_dir/upload-error"
				exit 0 # exit script
			else
				# Upload file to the movie folder
				echo "Uploading file to ${drive_names[i]}......"
				while true
				do
					result=`gdrive --config ${gdrive_config_paths[i]} upload --parent "$mov_folder" $f`
					
					# Check result of upload
					if [[ $result == *"Error"* ]] && [[ $result == *"rateLimitExceeded"* ]]
					then
						wait_time=$((wait_time * 2))
						echo "Rate Limit Exceeded, waiting $wait_time seconds"
						echo "$(date +%F_%T) RateLimitExceeded mov:${drive_names[i]}:$folder:$out" >> "$plexidrive_dir/upload-error"
						sleep $wait_time					
					elif [[ $out =~ "Error \d{3}" ]] && [[ $out != *"rateLimitExceeded"* ]]
					then
						echo "Unknown error! Halting program."
						gdrive --config ${gdrive_config_paths[i]} delete $mov_folder
						echo "$(date +%F_%T) UnknownError mov:${drive_names[i]}:$folder:$out" >> "$plexidrive_dir/upload-error"
						exit 0 # terminate the script
					else
						echo "success!"
						break # exit loop
					fi
				done
				break # exit loop
			fi
		done

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
done

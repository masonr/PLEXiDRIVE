#!/bin/bash

# Directory where this file exists
plexidrive_dir=`dirname $0`
cd "$plexidrive_dir"

# Read in configuration file
if [ -e ./plexidrive.conf ] ; then
	source ./plexidrive.conf
else
	echo "Configuration file - plexidrive.conf - not found."
	echo "$(date +%F_%T) Configuration file - plexidrive.conf - not found." >> "$plexidrive_dir/upload-error"
	exit 1
fi

# Create blank files if they don't exist yet
touch ./plex-scan
touch ./upload-error
touch ./gdrive-directory

# Check variables
if [ "$num_of_gdrives" -ne ${#drive_names[@]} ] || [ "$num_of_gdrives" -ne ${#gdrive_config_paths[@]} ] || [ "$num_of_gdrives" -ne ${#gdrive_mount_paths[@]} ] ; then
	echo "gdrive variables are not set up correctly! Exiting..."
	echo "$(date +%F_%T) gdrive variables are not set up correctly! Exiting." >> "$plexidrive_dir/upload-error"
	exit 1
fi

##################################################################################
################################ TV SHOWS UPLOADS ################################
##################################################################################

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

	# Add season folder to list of directories for plex to scan
	desc="$show:$season:"
	check=`cat $plexidrive_dir/plex-scan | grep $desc`
	if [ -z "$check" ]
	then
		echo "tv:$desc" >> "$plexidrive_dir/plex-scan"
	fi

	# Upload file to every Google drive account
	for (( i=0; i<${num_of_gdrives}; i++ ));
	do
		wait_time=1

		# Check if season folder exists
		check=`cat $plexidrive_dir/gdrive-directory | grep "${drive_names[i]}:$show:$season::"`
		if [ ! -z "$check" ]
		then # Season folder for this show exists
			folder=${check##*::}
		else # Season folder for this show DOES NOT exist
			# Check if show folder exists
			check=`cat $plexidrive_dir/gdrive-directory | grep "${drive_names[i]}:$show::"`
			if [ -e "$check" ]
			then # Show folder exists, create season folder within
				parent=${check##*::}
			else # Show folder DOES NOT exist (new show), create show folder
				while true
				do
					tv_root=`cat $plexidrive_dir/gdrive-directory | grep "${drive_names[i]}:TV_ROOT::"`
					out=`gdrive --config ${gdrive_config_paths[i]} mkdir --parent ${tv_root##*::} "$show"`
					# Check if directory was created successfully
					if  [[ $out == *"Error"* ]] && [[ $out == *"rateLimitExceeded"* ]]
					then
						wait_time=$((wait_time * 2))
						echo "Rate Limit Exceeded, waiting $wait_time seconds."
						echo "$(date +%F_%T) tv:${drive_names[i]}:$f:$out" >> "$plexidrive_dir/upload-error"
						sleep $wait_time
					elif [[ $out =~ "Error \d{3}" ]] && [[ $out != *"rateLimitExceeded"* ]]
					then
						echo "Unknown Error, exiting script."
						echo "$(date +%F_%T) tv:${drive_names[i]}:$f:$out" >> "$plexidrive_dir/upload-error"
						exit 1 # exit script
					else
						parent=`echo $out | head -n1 | awk '{print $2;}'`
						echo "${drive_names[i]}:$show::$parent" >> "$plexidrive_dir/gdrive-directory"
						break # exit loop
					fi
				done
			fi
			while true
			do
				# Create the season folder within the show folder
				out=`gdrive --config ${gdrive_config_paths[i]} mkdir --parent "$parent" "$season"`
				# Check if directory was created successfully
				if  [[ $out == *"Error"* ]] && [[ $out == *"rateLimitExceeded"* ]]
				then
					wait_time=$((wait_time * 2))
					echo "Rate Limit Exceeded, waiting $wait_time seconds."
					echo "$(date +%F_%T) tv:${drive_names[i]}:$f:$out" >> "$plexidrive_dir/upload-error"
					sleep $wait_time
				elif [[ $out =~ "Error \d{3}" ]] && [[ $out != *"rateLimitExceeded"* ]]
				then
					echo "Unknown Error, exiting script."
					echo "$(date +%F_%T) tv:${drive_names[i]}:$f:$out" >> "$plexidrive_dir/upload-error"
					exit 1 # exit script
				else
					folder=`echo $out | head -n1 | awk '{print $2;}'`
					echo "${drive_names[i]}:$show:$season::$folder" >> "$plexidrive_dir/gdrive-directory"
					break # exit loop
				fi
			done
		fi

		# Upload file to the show folder
		echo "Uploading file to ${drive_names[i]}......"
		while true
		do
			result=`gdrive --config ${gdrive_config_paths[i]} upload --parent "$folder" $f`

			# Check result of upload
			if [[ $result == *"Error"* ]] && [[ $result == *"rateLimitExceeded"* ]]
			then
				wait_time=$((wait_time * 2))
				echo "Rate Limit Exceeded, waiting $wait_time seconds."
				echo "$(date +%F_%T) tv:${drive_names[i]}:$f:$result" >> "$plexidrive_dir/upload-error"
				sleep $wait_time
			elif [[ $result =~ "Error \d{3}" ]] && [[ $result != *"rateLimitExceeded"* ]]
			then
				echo "Unknown Error, exiting script."
				echo "$(date +%F_%T) tv:${drive_names[i]}:$f:$out" >> "$plexidrive_dir/upload-error"
				exit 1 # exit script	
			else
				echo "success!"
				break
			fi
		done
	done

	# Delete local file after sucessful upload, if enabled
	if [ "$delete_after_upload" = true ] ; then
		# Delete the local file
		rm "$f"
	fi
done

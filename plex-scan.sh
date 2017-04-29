#!/bin/bash

##################################################################################
################################### PLEXiDRIVE ###################################
#################################### PLEX SCAN ###################################
##################################################################################

# Directory where this file exists
plexidrive_dir=`dirname $0`
cd "$plexidrive_dir"

# Log
echo "+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+" >> "$plexidrive_dir/plex-scan.log"
echo "$(date +%F_%T) Starting plex scan." >> "$plexidrive_dir/plex-scan.log"

# Check if file is empty
if [ -s "$plexidrive_dir/plex-scan" ]
then

	# Upload file to every Google drive account
	for (( i=0; i<${num_of_gdrives}; i++ ));
	do
		out=`ls $gdrive_mount_paths`
		if [ -z $out ]
		then
			echo "A gdrive accounts is not mounted."
			echo "$(date +%F_%T) plex-scan:${drive_names[i]} not mounted" >> "$plexidrive_dir/plex-scan.log"
			exit 1 # exit the script
		fi
	done

	unset n
	while read -r line; do
		echo $line
	
		IFS=':' read -a current <<< "$line"
	
		if [ "tv" = "${current[0]}" ]
		then
			# Dealing with a TV show
			show="${current[1]}"
			season="${current[2]}"
			echo "Plex Scanner: Scanning $season of $show."
			path="$plex_tvshow_path/$show/$season/"
			export LD_LIBRARY_PATH=/usr/lib/plexmediaserver
			/usr/lib/plexmediaserver/Plex\ Media\ Scanner --scan --refresh -c 2 -d "$path"
			echo "Plex Scanner: Done scanning $season of $show."
		elif [ "mov" = "${current[0]}" ]
		then
			# Dealing with a movie
			folder="${current[1]}"
			path="$plex_movies_path/$folder"
			echo "Plex Scanner: Scanning the movie - $folder."
			export LD_LIBRARY_PATH=/usr/lib/plexmediaserver
			/usr/lib/plexmediaserver/Plex\ Media\ Scanner --scan --refresh -c 3 -d "$path"
			echo "Plex Scanner: Done scanning movie - $folder."
		fi

		echo "- Scanned: $line" >> "$plexidrive_dir/plex-scan.log"
	
		: $[n++]
	done < "$plexidrive_dir/plex-scan"
	sed -i "1,$n d" "$plexidrive_dir/plex-scan"
fi


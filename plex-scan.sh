#!/bin/bash

##################################################################################
################################### PLEXiDRIVE ###################################
#################################### PLEX SCAN ###################################
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

# Log
echo "+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+" >> "$plexidrive_dir/plex-scan.log"
echo "$(date +%F_%T) Starting plex scan." >> "$plexidrive_dir/plex-scan.log"

# Check if file is empty
if [ -s "$plexidrive_dir/plex-scan" ]
then

	# Check if each mount path are sucessfully mounted, if enabled
	if [[ ! -d "$plex_tvshow_path" && "$enable_show_uploads" = "true" ]] || [[ ! -d "$plex_movies_path" && "$enable_movie_uploads" = "true" ]]
	then
		echo "At least one plex path is not mounted."
		echo "$(date +%F_%T) plex-scan: at least one plex path is not mounted" >> "$plexidrive_dir/plex-scan.log"
		echo "$(date +%F_%T) plex-scan: at least one plex path is not mounted" >> "$plexidrive_dir/upload-error"
		exit 1 # exit the script
	fi

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
			/usr/lib/plexmediaserver/Plex\ Media\ Scanner --scan --refresh -c "$plex_tvshow_section_num" -d "$path"
			echo "Plex Scanner: Done scanning $season of $show."
		elif [ "mov" = "${current[0]}" ]
		then
			# Dealing with a movie
			folder="${current[1]}"
			path="$plex_movies_path/$folder"
			echo "Plex Scanner: Scanning the movie - $folder."
			export LD_LIBRARY_PATH=/usr/lib/plexmediaserver
			/usr/lib/plexmediaserver/Plex\ Media\ Scanner --scan --refresh -c "$plex_movies_section_num" -d "$path"
			echo "Plex Scanner: Done scanning movie - $folder."
		fi

		echo "- Scanned: $line" >> "$plexidrive_dir/plex-scan.log"
	
		: $[n++]
	done < "$plexidrive_dir/plex-scan"
	sed -i "1,$n d" "$plexidrive_dir/plex-scan"
fi


#!/usr/bin/env bash

JSON_FILES=( "$@" )

# Process all files
for JSON_FILE in "${JSON_FILES[@]}"; do
	if [ -r "$JSON_FILE" ]; then
		# Prepare JQ command
		JQ_CMD=""

		# Process all keys
		KEYS=$(jq -r -c 'path(..)|[.[]|tostring]|join("/")' "$JSON_FILE")
		for KEY in $KEYS; do
			# Build environment key
			ENV_KEY=${KEY^^}
			ENV_KEY=${ENV_KEY//\//_}

			# Check if environment variable is defined
			if [ -v "$ENV_KEY" ]; then
				# Build jq path
				JQ_PATH="."
				IFS='/' read -r -a PARTS <<< $KEY
				for PART in "${PARTS[@]}"; do
					JQ_PATH+="[\"$PART\"]"
				done

				# Complete JQ command
				[ "$JQ_CMD" != "" ] && JQ_CMD+=" | "
				ENV_VALUE=${!ENV_KEY}
				if [[ $ENV_VALUE == [* ]] || [[ $ENV_VALUE == \{* ]]; then
					JQ_CMD+="${JQ_PATH} = $ENV_VALUE"
				else
					JQ_CMD+="${JQ_PATH} = env.$ENV_KEY"
				fi
			fi
		done

		# Execute JQ command
		JQ_CMD="jq -M --tab '${JQ_CMD:-.}' $JSON_FILE"
		eval "$JQ_CMD" > "${JSON_FILE}.tmp"
		if [ $? -eq 0 ]; then
			cat "${JSON_FILE}.tmp" > "$JSON_FILE"
		fi
		rm "${JSON_FILE}.tmp"
	fi
done
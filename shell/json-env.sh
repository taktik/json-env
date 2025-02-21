#!/usr/bin/env bash

# Usage function
usage() {
	echo "Usage: $0 [-p PREFIX] <json_file1> [json_file2 ...]"
	echo "  -p, --prefix PREFIX  Only apply environment variables with this prefix"
	exit 1
}

# Parse optional prefix argument
PREFIX=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		-p|--prefix)
			PREFIX="$2"
			shift 2
			;;
		-h|--help)
			usage
			;;
		--) # End of options
			shift
			break
			;;
		-*)
			echo "Unknown option: $1" >&2
			usage
			;;
		*)
			break
			;;
	esac
done

# Ensure at least one JSON file is provided
if [[ $# -eq 0 ]]; then
	echo "Error: No JSON files specified." >&2
	usage
fi

# Process each JSON file
for JSON_FILE in "$@"; do
	# Check if the file exists and is readable
	if [[ ! -r "$JSON_FILE" ]]; then
		echo "Skipping '$JSON_FILE': File not found or not readable." >&2
		continue
	fi

	# Prepare JQ transformation command
	JQ_CMD="."

	# Extract all JSON keys as paths, using '/' as a separator
	while IFS= read -r KEY; do
		# Primary environment variable lookup: Use '.' notation as-is
		ENV_KEY="${PREFIX}${KEY//\//.}"

		# Fallback lookup: Convert '.' to '_' and uppercase for compatibility
		FALLBACK_ENV_KEY="${PREFIX}${KEY^^}"      # Uppercase
		FALLBACK_ENV_KEY="${FALLBACK_ENV_KEY//\//_}"  # Replace '/' with '_'

		# Determine which environment variable to use
		if [[ -v "$ENV_KEY" ]]; then
			ENV_VALUE="${!ENV_KEY}"
		elif [[ -v "$FALLBACK_ENV_KEY" ]]; then
			ENV_VALUE="${!FALLBACK_ENV_KEY}"
		else
			# Skip if no matching environment variable is found
			continue
		fi

		# Build jq path notation
		JQ_PATH="."
		IFS='/' read -ra PARTS <<< "$KEY"
		for PART in "${PARTS[@]}"; do
			JQ_PATH+="[\"$PART\"]"
		done

		# Detect existing JSON type
		JSON_TYPE=$(jq -r "$JQ_PATH | type" "$JSON_FILE" 2>/dev/null)

		# Convert ENV_VALUE based on detected JSON type
		case "$JSON_TYPE" in
			boolean)
				if [[ "$ENV_VALUE" =~ ^(true|false)$ ]]; then
					VALUE="$ENV_VALUE"
				else
					VALUE="false" # Fallback
				fi
				;;
			number)
				if [[ "$ENV_VALUE" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
					VALUE="$ENV_VALUE"
				else
					VALUE="0" # Fallback
				fi
				;;
			null)
				VALUE="null"
				;;
			array|object)
				VALUE="$ENV_VALUE" # Assume valid JSON
				;;
			string|*)
				VALUE="\"$ENV_VALUE\""
				;;
		esac

		# Append the transformation to JQ command
		JQ_CMD+=" | ${JQ_PATH} = $VALUE"
	done < <(jq -r -c 'path(..) | map(tostring) | join("/")' "$JSON_FILE")

	# Apply jq transformation if changes are needed
	if [[ "$JQ_CMD" != "." ]]; then
		TEMP_FILE="${JSON_FILE}.tmp"
		if jq -M --tab "$JQ_CMD" "$JSON_FILE" > "$TEMP_FILE"; then
			mv "$TEMP_FILE" "$JSON_FILE"
		else
			echo "Error processing '$JSON_FILE' with jq." >&2
			rm -f "$TEMP_FILE"
		fi
	fi
done

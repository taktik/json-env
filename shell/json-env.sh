#!/usr/bin/env bash

# Ensure at least one JSON file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <json_file1> [json_file2 ...]" >&2
    exit 1
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

    # Extract all JSON keys as paths
    while IFS= read -r KEY; do
        # Convert JSON key path to an environment variable key (uppercase + underscores)
        ENV_KEY=${KEY^^}         # Convert to uppercase
        ENV_KEY=${ENV_KEY//\//_} # Replace '/' with '_'

        # Check if corresponding environment variable exists
        if [[ -v "$ENV_KEY" ]]; then
            # Build jq path notation
            JQ_PATH="."
            IFS='/' read -ra PARTS <<< "$KEY"
            for PART in "${PARTS[@]}"; do
                JQ_PATH+="[\"$PART\"]"
            done

            # Assign value from environment variable
            ENV_VALUE="${!ENV_KEY}"
            if [[ "$ENV_VALUE" == \[* || "$ENV_VALUE" == \{* ]]; then
                JQ_CMD+=" | ${JQ_PATH} = $ENV_VALUE"  # Raw JSON value
            else
                JQ_CMD+=" | ${JQ_PATH} = env.$ENV_KEY"  # String value from environment
            fi
        fi
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

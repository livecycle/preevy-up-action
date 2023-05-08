# Convert the docker-compose-yaml-path input to an env var
compose_file_path=${{ inputs.docker-compose-yaml-path }}

# Run the up command
preevy up ${compose_file_path:+-f ${compose_file_path}} ${{ inputs.args }}

# Fetch the generated preevy urls
urls_json=$(preevy urls ${compose_file_path:+-f ${compose_file_path}} --json)

# Format urls into a markdown table and store them in urls.txt
cat << EOF > urls.txt
| Service | Port | URL |
|---------|------|-----|
$(echo $urls_json | jq -r '.[] | {service, port, url} | join(" | ") | "| " + . + " |" ')
EOF

# Create a delimiter as detailed here: https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#multiline-strings
EOF=$(dd if=/dev/urandom bs=15 count=1 status=none | base64)

# Create the urls-markdown output
echo "urls-markdown<<$EOF" >> $GITHUB_OUTPUT
cat urls.txt >> $GITHUB_OUTPUT
echo "$EOF" >> $GITHUB_OUTPUT

# Create the urls-json output
echo "urls-json<<$EOF" >> $GITHUB_OUTPUT
ehco $urls_json >> $GITHUB_OUTPUT
echo "$EOF" >> $GITHUB_OUTPUT
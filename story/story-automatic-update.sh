#!/bin/bash

# Global setting variables, typically uppercase
# Path to the JSON file
_UPGRADE_INFO_PATH="$HOME/.story/story/data/upgrade-info.json"

get_aws_story_binary_url() {
    local story_version="$1"
    echo "https://github.com/piplabs/story/releases/download/v${story_version}/story-linux-amd64"
}

get_aws_geth_binary_url() {
    local geth_version="$1"
    echo "https://github.com/piplabs/story-geth/releases/download/v${geth_version}/geth-linux-amd64"
}

# Function to check if the upgrade has already been done
check_if_upgrade_already_done() {
    if [ -f "$_UPGRADE_INFO_PATH" ]; then
        # Read the upgrade block height from the JSON file
        _UPGRADE_HEIGHT=$(jq -r '.height' "$_UPGRADE_INFO_PATH")

        # Check if the upgrade block height matches the condition block height
        if [ "$_UPGRADE_HEIGHT" -eq "$1" ]; then
            echo "Upgrade already performed at block height $_UPGRADE_HEIGHT. Skipping upgrade."
            return 0  # Return true if the upgrade was already done
        fi
    fi
    return 1  # Return false if the upgrade was not done
}

# Schedule an upgrade to the Story client
schedule_client_upgrade() {
    # Parameters for the function
    local upgrade_link="$1"
    local client_version="$2"
    local upgrade_height="$3"

    echo "Schedule an upgrade to the Story client"
    echo "upgrade_link=$upgrade_link"
    echo "client_version=$client_version"
    echo "upgrade_height=$upgrade_height"


    # Download and extract the Client
    echo "Download and extract the new client in progress..."
    wget "$upgrade_link" -O "/tmp/story-$client_version"
    sudo chmod a+x "/tmp/story-$client_version"

    # Get the full path of the client executable
    client_path="/tmp/story-$client_version"

    # Run the command to schedule the upgrade
    if [ "$upgrade_height" -eq 0 ]; then
      echo "Immediately upgrade to the new client."
      cosmovisor add-upgrade "$client_version" "$client_path" --force
    else
      echo "Scheduling the upgrade to the new client."
      cosmovisor add-upgrade "$client_version" "$client_path" --force --upgrade-height "$upgrade_height"
    fi

    echo "Upgrade scheduled successfully!"
}

upgrade_geth() {
	local geth_version="$1"
	wget -q $(get_aws_geth_binary_url "$geth_version") -O /tmp/story-geth
    mkdir -p $HOME/go/bin
    sudo chmod a+x /tmp/story-geth
    sudo cp /tmp/story-geth $HOME/go/bin/story-geth
    sudo systemctl restart story-geth
}

check_geth_version() {
	local geth_version="$1"
    if geth version 2>&1 | grep -q $geth_version; then
        echo true
    else
        echo false
    fi
}

# Check the block height and run the upgrade
while true; do
    # Fetch current block height
    LATEST_BLOCK_HEIGHT=$($HOME/.story/story/cosmovisor/genesis/bin/story status | jq .sync_info.latest_block_height | xargs)

    echo "Current block height: $LATEST_BLOCK_HEIGHT"

	if [ "$LATEST_BLOCK_HEIGHT" -ge 1143000 ]; then
    	# Upgrade the geth: v0.10.1 -> v0.11.0
        # Check if the upgrade has already been performed
        if check_geth_version 1143000; then
            echo "No need to perform the upgrade again."
        else
            echo "Block height $LATEST_BLOCK_HEIGHT has reached 1143000."
            upgrade_geth "0.11.0"
        fi
    elif [ "$LATEST_BLOCK_HEIGHT" -ge 322000 ]; then
        # Upgrade the node: v0.12.1 -> v0.13.0
        # Check if the upgrade has already been performed
        if check_if_upgrade_already_done 858000; then
            echo "No need to perform the upgrade again."
        else
            echo "Block height $LATEST_BLOCK_HEIGHT has reached 858000."
            schedule_client_upgrade "$(get_aws_story_binary_url "0.13.0")" "v0.13.0" 858000
        fi
    elif [ "$LATEST_BLOCK_HEIGHT" -ge 1 ]; then
        # Upgrade the node: v0.12.0 -> v0.12.1
        # Check if the upgrade has already been performed
        if check_if_upgrade_already_done 626575; then
            echo "No need to perform the upgrade again."
        else
            echo "Block height $LATEST_BLOCK_HEIGHT has reached 1."
            schedule_client_upgrade "$(get_aws_story_binary_url "0.12.1")" "v0.12.1" 322000
        fi
    fi

    sleep 5
done

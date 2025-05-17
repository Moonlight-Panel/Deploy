#!/bin/bash

set -e

source .env

echo "[i] Updating your moonlight instance"

echo "[i] Checking for updates on deploy repo"

# Fetch remote updates
git fetch

# Get current branch name
branch=$(git rev-parse --abbrev-ref HEAD)

# Compare local and remote branch
local_commit=$(git rev-parse "$branch")
remote_commit=$(git rev-parse "origin/$branch")

if [ "$local_commit" != "$remote_commit" ]; then
    echo "[i] The deploy repository has updates. Fetching changes"
    git pull
    echo "[i] Updated deploy tools. Please rerun the update.sh"
    exit 0
else
    echo "[i] No update of the deploy repository available"
fi

if [ "$MOONLIGHT_BUILD" == "build" ]; then
    echo "[i] Rebuilding the docker image"
    docker compose build
    echo "[i] Rebuild done"
fi

if [ "$MOONLIGHT_BUILD" == "pull" ]; then
    echo "[i] Pulling the latest docker image"
    docker compose build
    echo "[i] Pulling completed"
fi

echo "[i] Stopping containers"
docker compose down

echo "[i] Starting containers"
docker compose up -d

echo "[i] Update done :>"
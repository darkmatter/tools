#! /usr/bin/env bash

# Forward a local port to the docker daemon on a remote server via SSH
# Enables testcontainers to use the remote docker daemon
# Usage:
# source ./extra/docker-tunnel.sh
# go test ./...

# Kill any existing SSH tunnel
lsof -i :2375 -t | xargs kill -9 > /dev/null 2>&1 && \
  echo "Killed existing SSH tunnel to remote Docker..." >&2

# Create a temporary SSH config file
SSH_CONFIG_FILE=$(mktemp)
cat > "$SSH_CONFIG_FILE" <<EOF
Host darkmatter-remote-dev
  HostName drkmttr-hz-de.tail6277a6.ts.net
  User $DM_USERNAME
  StrictHostKeyChecking no
  LocalForward 2375 localhost:2375
EOF

# Only run ssh if not already established
if ! pgrep -f "ssh.*-F \"$SSH_CONFIG_FILE\" darkmatter-remote-dev" >/dev/null; then
  echo "Setting up SSH tunnel to remote Docker..." >&2
  ssh -f -N -F "$SSH_CONFIG_FILE" darkmatter-remote-dev -o StrictHostKeyChecking=no
  echo "🛜 Remote Docker tunnel established"
else
  echo "🟢 SSH tunnel already established - to kill it run:"
  echo "  lsof -i :2375 -t | xargs kill -9"
fi

# leaving here as reference since they do affect behavior but were not needed
#
# export TESTCONTAINERS_DOCKER_HOST="drkmttr-hz-de"
# export DOCKER_TLS_VERIFY="0"

export TESTCONTAINERS_DOCKER_CLIENT_STRATEGY="org.testcontainers.dockerclient.EnvironmentAndSystemPropertyClientProviderStrategy"
export DOCKER_HOST=tcp://localhost:2375
export TESTCONTAINERS_HOST_OVERRIDE=drkmttr-hz-de

echo "Note: All docker commands in this shell will use the remote daemon until the tunnel is killed."
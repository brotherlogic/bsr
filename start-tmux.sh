#!/bin/bash

# Ensure the 'bsr' session exists
if ! tmux has-session -t bsr 2>/dev/null; then
  # Create a new session named 'bsr', detached
  cd /workspaces/bsr
  tmux new-session -d -s bsr
fi

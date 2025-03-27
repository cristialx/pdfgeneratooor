#!/bin/bash

# This script helps deploy and manage the PDF generation server

# Install dependencies
setup() {
  echo "Installing dependencies..."
  if [ ! -f "package.json" ]; then
    echo "Error: package.json not found! Make sure you're in the correct directory."
    exit 1
  fi
  npm install
}

# Start the server using PM2
start() {
  echo "Starting PDF generation server with PM2..."
  # Check if PM2 is installed
  if ! command -v pm2 &> /dev/null; then
    echo "PM2 is not installed. Installing PM2 globally..."
    npm install -g pm2
  fi
  pm2 start server.js --name "pdf-server"
}

# Stop the server
stop() {
  echo "Stopping PDF generation server..."
  pm2 stop pdf-server
}

# Restart the server
restart() {
  echo "Restarting PDF generation server..."
  pm2 restart pdf-server
}

# Check server status
status() {
  echo "Checking server status..."
  pm2 status pdf-server
}

# Update from git repository
update() {
  echo "Updating from git repository..."
  git pull
  npm install
  pm2 restart pdf-server
}

# Verify Chromium installation
verify_chromium() {
  echo "Verifying Chromium installation..."
  if ! command -v chromium-browser &> /dev/null; then
    echo "Chromium browser not found. Installing..."
    sudo apt-get update && sudo apt-get install -y chromium-browser
  else
    CHROMIUM_PATH=$(which chromium-browser)
    echo "Chromium browser found at: $CHROMIUM_PATH"
  fi
}

# Show help
help() {
  echo "PDF Generation Server deployment script"
  echo "Usage: ./deploy.sh [command]"
  echo ""
  echo "Commands:"
  echo "  setup    - Install dependencies"
  echo "  start    - Start the server with PM2"
  echo "  stop     - Stop the server"
  echo "  restart  - Restart the server"
  echo "  status   - Check server status"
  echo "  update   - Update from git repository and restart"
  echo "  verify   - Verify Chromium installation"
}

# Process command
case "$1" in
  setup)
    setup
    ;;
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    restart
    ;;
  status)
    status
    ;;
  update)
    update
    ;;
  verify)
    verify_chromium
    ;;
  *)
    help
    ;;
esac

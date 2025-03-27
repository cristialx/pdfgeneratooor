#!/bin/bash

# This script helps deploy and manage the PDF generation server

# Check if we're in the right directory (with package.json)
check_directory() {
  if [ ! -f "package.json" ]; then
    echo "Error: package.json not found. Make sure you're in the correct directory."
    exit 1
  fi
}

# Install dependencies
setup() {
  echo "Installing dependencies..."
  check_directory
  npm install
  
  # Check if PM2 is installed globally, if not install it
  if ! command -v pm2 &> /dev/null; then
    echo "PM2 not found. Installing PM2 globally..."
    npm install -g pm2
  fi
  
  echo "Setup completed successfully."
}

# Verify Chromium installation
verify() {
  echo "Verifying Chromium installation..."
  if ! command -v chromium-browser &> /dev/null; then
    echo "Chromium browser not found. Installing..."
    apt-get update && apt-get install -y chromium-browser
  else
    echo "Chromium browser found at: $(which chromium-browser)"
  fi
  
  # Check for other required dependencies
  echo "Checking for other required dependencies..."
  apt-get update && apt-get install -y \
    libasound2 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libnss3 \
    libpango-1.0-0
  
  echo "Verification completed."
}

# Start the server using PM2
start() {
  echo "Starting PDF generation server with PM2..."
  check_directory
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

# Show help
help() {
  echo "PDF Generation Server deployment script"
  echo "Usage: ./deploy.sh [command]"
  echo ""
  echo "Commands:"
  echo "  setup    - Install dependencies"
  echo "  verify   - Verify Chromium and other dependencies"
  echo "  start    - Start the server with PM2"
  echo "  stop     - Stop the server"
  echo "  restart  - Restart the server"
  echo "  status   - Check server status"
  echo "  update   - Update from git repository and restart"
}

# Process command
case "$1" in
  setup)
    setup
    ;;
  verify)
    verify
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
  *)
    help
    ;;
esac

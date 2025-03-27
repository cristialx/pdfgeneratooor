#!/bin/bash

# This script helps deploy and manage the PDF generation server

# Install dependencies
setup() {
  echo "Installing dependencies..."
  npm install
}

# Start the server using PM2
start() {
  echo "Starting PDF generation server with PM2..."
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

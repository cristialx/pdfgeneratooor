#!/bin/bash

# This script helps deploy and manage the PDF generation server

# Check if package.json exists
check_package_json() {
  if [ ! -f "package.json" ]; then
    echo "package.json not found! Creating base package.json..."
    cat > package.json << 'EOL'
{
  "name": "pdf-generation-server",
  "version": "1.0.0",
  "description": "A Node.js server for generating PDF resumes from HTML templates using Puppeteer",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "body-parser": "^1.20.2",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "puppeteer": "^21.0.0",
    "fs-extra": "^11.1.1",
    "dotenv": "^16.3.1"
  },
  "engines": {
    "node": ">=16.0.0"
  }
}
EOL
    echo "Created package.json file"
  fi
}

# Install dependencies
setup() {
  echo "Setting up PDF generation server..."
  check_package_json
  
  # Check if npm is installed
  if ! command -v npm &> /dev/null; then
    echo "npm not found! Installing Node.js and npm..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
  fi
  
  echo "Installing dependencies..."
  npm install
  
  # Check if PM2 is installed
  if ! command -v pm2 &> /dev/null; then
    echo "PM2 not found! Installing PM2 globally..."
    npm install -g pm2
  fi
}

# Verify Chromium installation
verify() {
  echo "Verifying system requirements..."
  
  # Check for Chromium browser
  if [ ! -f "/usr/bin/chromium-browser" ]; then
    echo "Chromium browser not found. Installing Chromium..."
    sudo apt-get update
    sudo apt-get install -y chromium-browser
  else
    echo "✓ Chromium browser is installed"
  fi
  
  # Verify other dependencies
  if ! command -v npm &> /dev/null; then
    echo "× npm is not installed. Please run ./deploy.sh setup"
    exit 1
  else
    echo "✓ npm is installed"
  fi
  
  if ! command -v pm2 &> /dev/null; then
    echo "× PM2 is not installed. Please run ./deploy.sh setup"
    exit 1
  else
    echo "✓ PM2 is installed"
  fi
  
  echo "System verification complete!"
}

# Start the server using PM2
start() {
  echo "Starting PDF generation server with PM2..."
  check_package_json
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
  
  # Stash any local changes before pulling
  echo "Saving local changes..."
  git stash
  
  # Pull the latest changes
  echo "Pulling latest changes..."
  git pull
  
  # Apply stashed changes if needed
  echo "Applying saved local changes..."
  git stash pop
  
  # Install dependencies
  check_package_json
  npm install
  
  # Restart the server
  pm2 restart pdf-server || pm2 start server.js --name "pdf-server"
}

# Show logs
logs() {
  echo "Showing server logs..."
  pm2 logs pdf-server
}

# Show help
help() {
  echo "PDF Generation Server deployment script"
  echo "Usage: ./deploy.sh [command]"
  echo ""
  echo "Commands:"
  echo "  setup    - Set up environment and install dependencies"
  echo "  verify   - Verify system requirements (Chromium, etc.)"
  echo "  start    - Start the server with PM2"
  echo "  stop     - Stop the server"
  echo "  restart  - Restart the server"
  echo "  status   - Check server status"
  echo "  update   - Update from git repository and restart"
  echo "  logs     - Show server logs"
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
  logs)
    logs
    ;;
  *)
    help
    ;;
esac

#!/bin/bash

# This script helps deploy and manage the PDF generation server

# Create package.json if it doesn't exist
create_package_json() {
  if [ ! -f "package.json" ]; then
    echo "Creating package.json..."
    cat > package.json << EOF
{
  "name": "pdf-generation-server",
  "version": "1.0.0",
  "description": "Server for generating PDF resumes",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "body-parser": "^1.20.2",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "puppeteer": "^20.7.3",
    "fs-extra": "^11.1.1",
    "dotenv": "^16.3.1"
  }
}
EOF
    echo "package.json created successfully"
  else
    echo "package.json already exists"
  fi
}

# Install dependencies
setup() {
  echo "Setting up PDF generation server..."
  create_package_json
  echo "Installing dependencies..."
  npm install
  
  # Check if PM2 is installed
  if ! command -v pm2 &> /dev/null; then
    echo "Installing PM2 globally..."
    npm install -g pm2
  fi
  
  # Check if Chromium is installed
  if ! command -v chromium-browser &> /dev/null; then
    echo "Installing Chromium browser..."
    apt-get update && apt-get install -y chromium-browser
  fi
  
  echo "Setup completed successfully!"
}

# Verify requirements
verify() {
  echo "Verifying requirements..."
  local all_good=true
  
  # Check Node.js
  if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed"
    all_good=false
  else
    echo "✅ Node.js is installed: $(node -v)"
  fi
  
  # Check PM2
  if ! command -v pm2 &> /dev/null; then
    echo "❌ PM2 is not installed"
    all_good=false
  else
    echo "✅ PM2 is installed: $(pm2 -v)"
  fi
  
  # Check Chromium
  if ! command -v chromium-browser &> /dev/null; then
    echo "❌ Chromium browser is not installed"
    all_good=false
  else
    echo "✅ Chromium browser is installed"
  fi
  
  # Check dependencies
  if [ ! -d "node_modules" ]; then
    echo "❌ Dependencies are not installed"
    all_good=false
  else
    echo "✅ Dependencies are installed"
  fi
  
  if [ "$all_good" = true ]; then
    echo "All requirements are met! 🎉"
  else
    echo "Some requirements are missing. Please run './deploy.sh setup' to install them."
  fi
}

# Safe update from git repository
safe_update() {
  echo "Safely updating from git repository..."
  
  # Stash any local changes
  git stash
  
  # Pull latest changes
  git pull
  
  # Create package.json if needed after pull
  create_package_json
  
  # Install dependencies
  npm install
  
  # Apply stashed changes if any
  git stash pop 2>/dev/null || echo "No stashed changes to apply"
  
  echo "Update completed successfully!"
}

# Check for processes using port 80
check_port_80() {
  echo "Checking for processes using port 80..."
  local processes=$(lsof -i :80 -t)
  
  if [ -z "$processes" ]; then
    echo "No processes found using port 80."
    return 0
  else
    echo "The following processes are using port 80:"
    for pid in $processes; do
      echo "Process ID: $pid"
      ps -f -p $pid
    done
    
    if [ "$1" = "kill" ]; then
      echo "Attempting to stop processes using port 80..."
      for pid in $processes; do
        echo "Stopping process $pid..."
        kill -15 $pid
        sleep 2
        
        # Check if process is still running
        if ps -p $pid > /dev/null; then
          echo "Process $pid did not stop with SIGTERM, using SIGKILL..."
          kill -9 $pid
          sleep 1
        fi
      done
      
      # Verify port is free now
      local remaining=$(lsof -i :80 -t)
      if [ -z "$remaining" ]; then
        echo "Port 80 is now free."
        return 0
      else
        echo "WARNING: Port 80 is still in use. Attempting SIGKILL on remaining processes..."
        for pid in $remaining; do
          echo "Forcefully killing process $pid..."
          kill -9 $pid
        done
        sleep 2
        
        # Final check
        if [ -z "$(lsof -i :80 -t)" ]; then
          echo "Port 80 is now free after forceful termination."
          return 0
        else
          echo "CRITICAL: Port 80 is still in use after all attempts. Manual intervention required."
          echo "Run 'sudo lsof -i :80' to identify the processes and 'sudo kill -9 <PID>' to terminate them."
          return 1
        fi
      fi
    fi
    
    return 1
  fi
}

# Start the server using PM2
start() {
  echo "Starting PDF generation server with PM2..."
  
  # First check if server is already running
  pm2 describe pdf-server > /dev/null
  if [ $? -eq 0 ]; then
    echo "Server is already running. Restarting..."
    pm2 restart pdf-server
  else
    # Force port 3000 regardless of .env settings
    PORT=3000 pm2 start server.js --name "pdf-server"
  fi
  
  # Verify the server started on port 3000
  sleep 2
  if lsof -i :3000 | grep -q node; then
    echo "Server started successfully on port 3000! 🚀"
  else
    echo "WARNING: Server may not have started correctly on port 3000. Check logs with 'pm2 logs pdf-server'."
  fi
}

# Stop the server
stop() {
  echo "Stopping PDF generation server..."
  
  # Stop the PM2 process if it exists
  pm2 describe pdf-server > /dev/null
  if [ $? -eq 0 ]; then
    echo "Stopping PM2 process 'pdf-server'..."
    pm2 stop pdf-server
    sleep 1
  else
    echo "No PM2 process named 'pdf-server' found."
  fi
  
  # Check for any Node.js processes on ports 3000 and 80
  echo "Checking for Node.js processes on ports..."
  
  # Check port 3000
  local node_on_3000=$(lsof -i :3000 -t)
  if [ ! -z "$node_on_3000" ]; then
    echo "Found processes on port 3000: $node_on_3000"
    echo "Terminating processes..."
    for pid in $node_on_3000; do
      kill -15 $pid
      sleep 1
      # Force kill if still running
      if ps -p $pid > /dev/null; then
        echo "Process $pid still running, force killing..."
        kill -9 $pid
      fi
    done
  else
    echo "No processes found on port 3000."
  fi
  
  # Check port 80
  local node_on_80=$(lsof -i :80 -t)
  if [ ! -z "$node_on_80" ]; then
    echo "Found processes on port 80: $node_on_80"
    echo "Terminating processes..."
    for pid in $node_on_80; do
      kill -15 $pid
      sleep 1
      # Force kill if still running
      if ps -p $pid > /dev/null; then
        echo "Process $pid still running, force killing..."
        kill -9 $pid
      fi
    done
  else
    echo "No processes found on port 80."
  fi
  
  # Final check
  if [ ! -z "$(lsof -i :3000 -t)" ]; then
    echo "WARNING: Port 3000 is still in use after stopping attempts."
  fi
  
  if [ ! -z "$(lsof -i :80 -t)" ]; then
    echo "WARNING: Port 80 is still in use after stopping attempts."
  else
    echo "Port 80 is free."
  fi
}

# Restart the server
restart() {
  echo "Restarting PDF generation server..."
  stop
  sleep 2
  start
}

# Check server status
status() {
  echo "Checking server status..."
  pm2 describe pdf-server > /dev/null
  if [ $? -eq 0 ]; then
    pm2 status pdf-server
  else
    echo "PM2 process 'pdf-server' is not running."
  fi
  
  # Check port usage
  echo -e "\nChecking port usage..."
  echo "Port 3000 (Node.js server):"
  lsof -i :3000 || echo "No process using port 3000"
  
  echo -e "\nPort 80 (Nginx):"
  lsof -i :80 || echo "No process using port 80"
  
  echo -e "\nNginx status:"
  systemctl status nginx --no-pager | head -n 10
}

# Update from git repository
update() {
  safe_update
  restart
}

# Setup nginx
setup_nginx() {
  echo "Setting up Nginx configuration..."
  if [ -f /etc/nginx/sites-available/pdf-server ]; then
    echo "Nginx configuration already exists."
  else
    echo "Creating Nginx configuration..."
    sudo cp nginx-config /etc/nginx/sites-available/pdf-server
    
    # Create symbolic link if it doesn't exist
    if [ ! -f /etc/nginx/sites-enabled/pdf-server ]; then
      sudo ln -s /etc/nginx/sites-available/pdf-server /etc/nginx/sites-enabled/
    fi
  fi
  
  # Check for processes using port 80
  check_port_80
  
  echo "Checking Nginx configuration..."
  sudo nginx -t
  
  if [ $? -eq 0 ]; then
    echo "Nginx configuration is valid. Restarting Nginx..."
    sudo systemctl restart nginx
  else
    echo "Nginx configuration is invalid. Please check the configuration file."
  fi
}

# Fix nginx issues
fix_nginx() {
  echo "Attempting to fix Nginx issues..."
  
  # Stop all potential processes that might be using port 80
  echo "Stopping all services that might use port 80..."
  stop
  
  # If the server is running under PM2, make sure it's stopped
  if pm2 describe pdf-server > /dev/null; then
    echo "Stopping PM2 process 'pdf-server'..."
    pm2 stop pdf-server
    sleep 2
  fi
  
  # Check for processes using port 80 and kill them
  check_port_80 "kill"
  
  # Verify port 80 is available
  if [ ! -z "$(lsof -i :80 -t)" ]; then
    echo "ERROR: Port 80 is still in use after all attempts. Cannot start Nginx."
    echo "Manual intervention required. Run 'sudo lsof -i :80' and kill processes manually."
    return 1
  fi
  
  # Restart Nginx now that port 80 is free
  echo "Port 80 is free. Restarting Nginx..."
  sudo systemctl restart nginx
  sleep 2
  
  # Check if Nginx started successfully
  if systemctl is-active nginx > /dev/null; then
    echo "Nginx started successfully! 🎉"
    
    # Start the PDF server on port 3000
    echo "Now starting PDF server on port 3000..."
    start
    return 0
  else
    echo "ERROR: Nginx failed to start even though port 80 is free."
    echo "Check Nginx logs with 'sudo journalctl -xeu nginx.service' for more details."
    return 1
  fi
}

# Show help
help() {
  echo "PDF Generation Server deployment script"
  echo "Usage: ./deploy.sh [command]"
  echo ""
  echo "Commands:"
  echo "  setup       - Install dependencies and prepare environment"
  echo "  verify      - Check if all requirements are met"
  echo "  start       - Start the server with PM2"
  echo "  stop        - Stop the server"
  echo "  restart     - Restart the server"
  echo "  status      - Check server status"
  echo "  update      - Safely update from git repository and restart"
  echo "  setup_nginx - Set up Nginx as a reverse proxy"
  echo "  fix_nginx   - Attempt to fix Nginx issues (kills processes using port 80)"
  echo "  check_port  - Check what process is using port 80"
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
  setup_nginx)
    setup_nginx
    ;;
  fix_nginx)
    fix_nginx
    ;;
  check_port)
    check_port_80
    ;;
  *)
    help
    ;;
esac


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
    lsof -i :80
    
    if [ "$1" = "kill" ]; then
      echo "Attempting to stop processes using port 80..."
      for pid in $processes; do
        echo "Stopping process $pid..."
        kill -15 $pid
        sleep 1
      done
      echo "Done stopping processes."
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
    # Ensure we're using port 3000 as specified in .env
    PORT=3000 pm2 start server.js --name "pdf-server"
  fi
  echo "Server started successfully! 🚀"
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
  
  # Check for processes using port 80 and kill them if requested
  check_port_80 "kill"
  
  echo "Restarting Nginx..."
  sudo systemctl restart nginx
  
  if [ $? -eq 0 ]; then
    echo "Nginx started successfully! 🎉"
  else
    echo "Failed to start Nginx. Check if another process is still using port 80."
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

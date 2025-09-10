#!/bin/bash

# Script to fix missing app.py and set up BGP Learning Platform properly
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info "Fixing missing BGP Learning Platform files..."

# Stop service
info "Stopping bgp-learning service..."
systemctl stop bgp-learning || true

# Find source files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

# Check if we can find the source backend directory
BACKEND_SOURCE=""
FRONTEND_SOURCE=""

POSSIBLE_SOURCES=(
    "$SOURCE_DIR"
    "/var/project/bgp_learn/bgp-learning-site"
    "/tmp/bgp-learning-site"
    "$(pwd)"
    "$(dirname "$(pwd)")"
)

for source_path in "${POSSIBLE_SOURCES[@]}"; do
    if [[ -d "$source_path/backend" && -f "$source_path/backend/app.py" ]]; then
        BACKEND_SOURCE="$source_path/backend"
        info "Found backend source at: $BACKEND_SOURCE"
        break
    fi
done

for source_path in "${POSSIBLE_SOURCES[@]}"; do
    if [[ -d "$source_path/frontend" && -f "$source_path/frontend/index.html" ]]; then
        FRONTEND_SOURCE="$source_path/frontend"
        info "Found frontend source at: $FRONTEND_SOURCE"
        break
    fi
done

if [[ -z "$BACKEND_SOURCE" ]]; then
    error "Could not find backend source directory with app.py file"
    error "Please ensure you're running this from the bgp-learning-site directory"
    error "Or that the backend/app.py file exists"
    exit 1
fi

if [[ -z "$FRONTEND_SOURCE" ]]; then
    error "Could not find frontend source directory with index.html file"
    exit 1
fi

# Copy backend files
info "Copying backend files from: $BACKEND_SOURCE"
mkdir -p /opt/bgp-learning
cp -r "$BACKEND_SOURCE"/* /opt/bgp-learning/

# Copy frontend files
info "Copying frontend files from: $FRONTEND_SOURCE"
mkdir -p /var/www/bgp-learning
cp -r "$FRONTEND_SOURCE"/* /var/www/bgp-learning/

# Set up log file permissions
info "Setting up log file permissions..."
mkdir -p /var/log
touch /var/log/bgp-learning.log
chown bgplearning:bgplearning /var/log/bgp-learning.log
chmod 644 /var/log/bgp-learning.log

# Fix ownership
info "Setting correct ownership..."
chown -R bgplearning:bgplearning /opt/bgp-learning
chown -R www-data:www-data /var/www/bgp-learning

# Make sure virtual environment is executable
chmod +x /opt/bgp-learning/venv/bin/*

# Verify files are in place
info "Verifying files..."
if [[ ! -f "/opt/bgp-learning/app.py" ]]; then
    error "app.py is still missing after copy operation"
    exit 1
fi

if [[ ! -f "/opt/bgp-learning/requirements.txt" ]]; then
    error "requirements.txt is missing"
    exit 1
fi

success "Files copied successfully"

# Test import
info "Testing Python import..."
cd /opt/bgp-learning
if sudo -u bgplearning /opt/bgp-learning/venv/bin/python -c "import app; print('Import successful')"; then
    success "Application imports successfully"
else
    error "Application import still fails"
    error "Checking Python path and dependencies..."
    
    # Debug information
    echo "=== DEBUG INFO ==="
    echo "Working directory: $(pwd)"
    echo "Files in directory:"
    ls -la /opt/bgp-learning/
    echo "Python version:"
    sudo -u bgplearning /opt/bgp-learning/venv/bin/python --version
    echo "Installed packages:"
    sudo -u bgplearning /opt/bgp-learning/venv/bin/pip list
    exit 1
fi

# Try to run the application manually for a moment
info "Testing application startup..."
timeout 5 sudo -u bgplearning /opt/bgp-learning/venv/bin/python app.py &
APP_PID=$!
sleep 2

# Check if app is running
if kill -0 $APP_PID 2>/dev/null; then
    # Test API call
    if curl -s http://127.0.0.1:5000/api/lessons/first > /dev/null; then
        success "Application starts and responds to API calls"
    else
        warning "Application starts but API test failed"
    fi
    # Kill the test process
    kill $APP_PID 2>/dev/null || true
else
    warning "Application failed to start manually"
fi

# Start systemd service
info "Starting systemd service..."
systemctl daemon-reload
systemctl start bgp-learning

# Check service status
sleep 3
if systemctl is-active --quiet bgp-learning; then
    success "BGP Learning service is running"
    
    # Test API through service
    if curl -s http://127.0.0.1:5000/api/lessons/first > /dev/null; then
        success "API is responding through systemd service"
    else
        warning "Service running but API test failed"
    fi
else
    error "Service failed to start"
    echo "=== SERVICE LOGS ==="
    journalctl -u bgp-learning -n 20 --no-pager
    exit 1
fi

# Test nginx
info "Testing nginx configuration..."
if systemctl is-active --quiet nginx; then
    success "Nginx is running"
    if curl -k -s https://bgp.sapr.local/ > /dev/null; then
        success "HTTPS site is accessible"
    else
        warning "HTTPS site test failed"
    fi
else
    warning "Nginx is not running"
fi

success "BGP Learning Platform setup completed!"
echo
echo "=== ACCESS INFORMATION ==="
echo "• HTTPS: https://bgp.sapr.local/"
echo "• HTTP API: http://127.0.0.1:5000/api/lessons/first"
echo "• Service status: systemctl status bgp-learning"
echo "• Logs: journalctl -u bgp-learning -f"
echo
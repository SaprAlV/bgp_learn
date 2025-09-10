#!/bin/bash

# Script to fix BGP Learning Platform permissions
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

info "Fixing BGP Learning Platform permissions..."

# Stop service first
info "Stopping bgp-learning service..."
systemctl stop bgp-learning || true

# Fix log file permissions
info "Setting up log file permissions..."
mkdir -p /var/log
touch /var/log/bgp-learning.log
chown bgplearning:bgplearning /var/log/bgp-learning.log
chmod 644 /var/log/bgp-learning.log

# Copy updated app.py files
info "Updating application files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

if [[ -f "$SOURCE_DIR/backend/app.py" ]]; then
    cp "$SOURCE_DIR/backend/app.py" /opt/bgp-learning/
    success "Updated app.py with permission fixes"
else
    warning "Source app.py not found, using existing file"
fi

# Fix application directory permissions
info "Fixing application directory permissions..."
chown -R bgplearning:bgplearning /opt/bgp-learning
chmod -R 755 /opt/bgp-learning
chmod +x /opt/bgp-learning/venv/bin/*

# Test the application
info "Testing application import..."
cd /opt/bgp-learning
if sudo -u bgplearning /opt/bgp-learning/venv/bin/python -c "import app; print('Import successful')"; then
    success "Application imports successfully"
else
    error "Application still has import issues"
    exit 1
fi

# Start service
info "Starting bgp-learning service..."
systemctl daemon-reload
systemctl start bgp-learning

# Check status
sleep 3
if systemctl is-active --quiet bgp-learning; then
    success "BGP Learning service is running"
    
    # Test API
    info "Testing API endpoint..."
    if curl -s -f http://127.0.0.1:5000/api/lessons/first > /dev/null; then
        success "API is responding"
    else
        warning "API test failed, but service is running"
    fi
else
    error "Service failed to start"
    systemctl status bgp-learning --no-pager -l
    exit 1
fi

success "Permission fixes completed successfully!"
echo
info "Service status:"
systemctl status bgp-learning --no-pager -l
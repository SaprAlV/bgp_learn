# 🔧 Fix Import Error for BGP Learning Service

## 🚨 Problem Identified
The gunicorn service can't import the Flask app module. This is typically because:
1. `app.py` file is missing in `/opt/bgp-learning/`
2. Python import path issues
3. Missing dependencies

## 🔍 Diagnostic Commands

Run these commands to identify the exact issue:

```bash
# 1. Check if app.py exists
ls -la /opt/bgp-learning/app.py

# 2. Check directory contents
ls -la /opt/bgp-learning/

# 3. Test Python import manually
cd /opt/bgp-learning
sudo -u bgplearning /opt/bgp-learning/venv/bin/python -c "import app; print('Import successful')"

# 4. Test Flask app directly
sudo -u bgplearning /opt/bgp-learning/venv/bin/python app.py
```

## 🛠️ Solution Steps

### Step 1: Ensure files are copied correctly
```bash
# Stop the service
sudo systemctl stop bgp-learning

# Check and copy files from source
cd /var/project/bgp_learn/bgp-learning-site
sudo cp backend/* /opt/bgp-learning/
sudo chown -R bgplearning:bgplearning /opt/bgp-learning

# Verify files are there
ls -la /opt/bgp-learning/
```

### Step 2: Test the application manually
```bash
cd /opt/bgp-learning
sudo -u bgplearning /opt/bgp-learning/venv/bin/python app.py
```

### Step 3: If app.py runs manually, fix the systemd service
```bash
# Create a proper systemd service file
sudo tee /etc/systemd/system/bgp-learning.service > /dev/null << 'EOF'
[Unit]
Description=BGP Learning Platform
After=network.target

[Service]
Type=exec
User=bgplearning
Group=bgplearning
WorkingDirectory=/opt/bgp-learning
Environment=PATH=/opt/bgp-learning/venv/bin:/usr/bin:/bin
Environment=PYTHONPATH=/opt/bgp-learning
ExecStart=/opt/bgp-learning/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 3 --timeout 120 --access-logfile - --error-logfile - app:app
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl start bgp-learning
sudo systemctl status bgp-learning
```

### Step 4: Alternative - Use Python directly instead of gunicorn
```bash
# If gunicorn still has issues, create a service that runs Python directly
sudo tee /etc/systemd/system/bgp-learning.service > /dev/null << 'EOF'
[Unit]
Description=BGP Learning Platform
After=network.target

[Service]
Type=exec
User=bgplearning
Group=bgplearning
WorkingDirectory=/opt/bgp-learning
Environment=PATH=/opt/bgp-learning/venv/bin:/usr/bin:/bin
Environment=FLASK_HOST=127.0.0.1
Environment=FLASK_PORT=5000
ExecStart=/opt/bgp-learning/venv/bin/python app.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# And modify app.py to run on the correct host/port
sudo tee -a /opt/bgp-learning/app.py > /dev/null << 'EOF'

if __name__ == '__main__':
    import os
    app.run(
        host=os.environ.get('FLASK_HOST', '127.0.0.1'),
        port=int(os.environ.get('FLASK_PORT', 5000)),
        debug=False
    )
EOF

sudo chown bgplearning:bgplearning /opt/bgp-learning/app.py
```

## 🚀 Quick Fix Commands

Execute these in order:

```bash
# 1. Stop service
sudo systemctl stop bgp-learning

# 2. Copy files
sudo cp /var/project/bgp_learn/bgp-learning-site/backend/* /opt/bgp-learning/
sudo chown -R bgplearning:bgplearning /opt/bgp-learning

# 3. Test manually
cd /opt/bgp-learning
sudo -u bgplearning /opt/bgp-learning/venv/bin/python -c "import app; print('SUCCESS: App imported')"

# 4. If import works, try running the app
sudo -u bgplearning /opt/bgp-learning/venv/bin/python app.py &
sleep 2
curl http://127.0.0.1:5000/api/lessons/first
kill %1

# 5. If manual test works, restart service
sudo systemctl start bgp-learning
sudo systemctl status bgp-learning
```

## 📊 Verification

After fixing:
```bash
# Check service status
sudo systemctl status bgp-learning --no-pager -l

# Check if port is listening
sudo netstat -tlnp | grep 5000

# Test API
curl http://127.0.0.1:5000/api/lessons/first

# Check nginx
sudo systemctl status nginx
curl https://bgp.sapr.local/
```

Run the diagnostic commands first and let me know the results!
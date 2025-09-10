# 🔧 Диагностика проблемы BGP Learning Service

## 🚨 Проблема
Сервис `bgp-learning.service` не запускается (exit-code status=1/FAILURE)

## 🔍 Шаги диагностики

### 1. Проверка детальных логов
```bash
# Подробные логи сервиса
sudo journalctl -u bgp-learning -n 50 --no-pager

# Логи в реальном времени
sudo journalctl -u bgp-learning -f
```

### 2. Проверка файлов приложения
```bash
# Проверка структуры директории
ls -la /opt/bgp-learning/

# Проверка наличия app.py
ls -la /opt/bgp-learning/app.py

# Проверка Python окружения
ls -la /opt/bgp-learning/venv/bin/

# Проверка прав доступа
sudo ls -la /opt/bgp-learning/
```

### 3. Тест запуска вручную
```bash
# Переход в директорию
cd /opt/bgp-learning

# Активация виртуального окружения
sudo -u bgplearning /opt/bgp-learning/venv/bin/python -c "import flask; print('Flask OK')"

# Тест запуска приложения
sudo -u bgplearning /opt/bgp-learning/venv/bin/python app.py

# Тест gunicorn
sudo -u bgplearning /opt/bgp-learning/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 1 app:app
```

### 4. Проверка зависимостей
```bash
# Проверка установленных пакетов
sudo -u bgplearning /opt/bgp-learning/venv/bin/pip list

# Переустановка зависимостей
cd /opt/bgp-learning
sudo -u bgplearning /opt/bgp-learning/venv/bin/pip install -r requirements.txt
```

## 🛠️ Возможные решения

### Решение 1: Исправление прав доступа
```bash
sudo chown -R bgplearning:bgplearning /opt/bgp-learning
sudo chmod +x /opt/bgp-learning/venv/bin/*
```

### Решение 2: Переустановка зависимостей
```bash
cd /opt/bgp-learning
sudo -u bgplearning /opt/bgp-learning/venv/bin/pip install --upgrade pip
sudo -u bgplearning /opt/bgp-learning/venv/bin/pip install flask flask-cors gunicorn --force-reinstall
```

### Решение 3: Исправление пути в systemd
```bash
# Проверка текущего сервиса
sudo systemctl cat bgp-learning

# Если нужно, создание нового сервиса
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
ExecStart=/opt/bgp-learning/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 3 --timeout 120 app:app
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

# Безопасность
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/bgp-learning /opt/bgp-learning

# Ограничения ресурсов
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузка конфигурации
sudo systemctl daemon-reload
sudo systemctl enable bgp-learning
sudo systemctl start bgp-learning
```

### Решение 4: Отладочная версия сервиса
```bash
# Временная отладочная версия
sudo tee /etc/systemd/system/bgp-learning-debug.service > /dev/null << 'EOF'
[Unit]
Description=BGP Learning Platform (Debug)
After=network.target

[Service]
Type=simple
User=bgplearning
Group=bgplearning
WorkingDirectory=/opt/bgp-learning
Environment=PATH=/opt/bgp-learning/venv/bin:/usr/bin:/bin
Environment=FLASK_ENV=development
Environment=FLASK_DEBUG=1
ExecStart=/opt/bgp-learning/venv/bin/python app.py
Restart=no
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Запуск отладочной версии
sudo systemctl daemon-reload
sudo systemctl start bgp-learning-debug
sudo journalctl -u bgp-learning-debug -f
```

## 🔧 Быстрое исправление

Выполните эти команды по порядку:

```bash
# 1. Остановка сервиса
sudo systemctl stop bgp-learning

# 2. Проверка файлов
ls -la /opt/bgp-learning/app.py
sudo chown -R bgplearning:bgplearning /opt/bgp-learning

# 3. Тест запуска вручную
cd /opt/bgp-learning
sudo -u bgplearning /opt/bgp-learning/venv/bin/python app.py

# 4. Если приложение запускается вручную, исправляем сервис:
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
ExecStart=/opt/bgp-learning/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 3 --timeout 120 app:app
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 5. Перезапуск
sudo systemctl daemon-reload
sudo systemctl start bgp-learning
sudo systemctl status bgp-learning
```

## 📊 Проверка результата

```bash
# Статус сервиса
sudo systemctl status bgp-learning --no-pager -l

# Логи последних 20 строк
sudo journalctl -u bgp-learning -n 20 --no-pager

# Проверка порта
sudo netstat -tlnp | grep 5000

# Тест API
curl http://127.0.0.1:5000/api/lessons/first
```

Запустите первые команды диагностики и пришлите результат - тогда я смогу дать точное решение!
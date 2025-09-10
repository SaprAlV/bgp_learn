# 🚀 Инструкция по установке BGP Learning Platform

## 📋 Системные требования

- **ОС**: Ubuntu 22.04 LTS (рекомендуется)
- **RAM**: минимум 2 GB
- **Диск**: 10 GB свободного места
- **Доступ**: root права (sudo)
- **Сеть**: доступ в интернет для установки пакетов

## 🔧 Быстрая установка (рекомендуется)

### 1. Подготовка файлов на сервере

Скопируйте папку `bgp-learning-site` на Ubuntu сервер любым способом:

**Через SCP (с Windows):**
```bash
scp -r "c:\pet\BGP_LEARN\bgp-learning-site" user@your-server:/tmp/
```

**Или через Git:**
```bash
git clone <your-repository>
```

### 2. Автоматическая установка

Подключитесь к Ubuntu серверу и выполните:

```bash
# Переход в директорию проекта
cd /tmp/bgp-learning-site  # или путь к вашим файлам

# Установка прав на выполнение
sudo chmod +x scripts/install.sh

# Запуск автоматической установки (различные варианты)

# Простая установка без SSL на localhost
sudo ./scripts/install.sh

# Установка с доменным именем без SSL
sudo ./scripts/install.sh -d bgp.example.com

# Установка с самоподписанным SSL сертификатом
sudo ./scripts/install.sh -d bgp.example.com --ssl self-signed

# Установка с Let's Encrypt SSL сертификатом
sudo ./scripts/install.sh -d bgp.example.com --ssl letsencrypt

# Показать справку по параметрам
sudo ./scripts/install.sh --help
```

**Интерактивная установка:**
Если запустить скрипт без параметров, он предложит ввести настройки:

```bash
sudo ./scripts/install.sh
# Затем следуйте инструкциям на экране
```

### 3. Проверка работы

После завершения установки:

```bash
# Проверка статуса сервисов
sudo systemctl status bgp-learning
sudo systemctl status nginx

# Проверка доступности
curl http://localhost/
curl http://localhost/api/lessons/first

# Полная диагностика
/usr/local/bin/bgp-learning-status
```

### 4. Открытие в браузере

Откройте в браузере: `http://IP-вашего-сервера/`

---

## 🛠️ Ручная установка (если автоматическая не сработала)

<details>
<summary>Развернуть пошаговую инструкцию</summary>

### Шаг 1: Обновление системы
```bash
sudo apt update && sudo apt upgrade -y
```

### Шаг 2: Установка зависимостей
```bash
sudo apt install -y python3 python3-pip python3-venv nginx git curl ufw
```

### Шаг 3: Создание пользователя приложения
```bash
sudo useradd -r -s /bin/false -d /opt/bgp-learning bgplearning
```

### Шаг 4: Создание директорий
```bash
sudo mkdir -p /opt/bgp-learning /var/log/bgp-learning /etc/bgp-learning
sudo chown -R bgplearning:bgplearning /opt/bgp-learning /var/log/bgp-learning
```

### Шаг 5: Установка Python окружения
```bash
cd /opt/bgp-learning
sudo -u bgplearning python3 -m venv venv
sudo -u bgplearning /opt/bgp-learning/venv/bin/pip install flask flask-cors gunicorn
```

### Шаг 6: Копирование файлов приложения
```bash
# Backend
sudo cp /tmp/bgp-learning-site/backend/* /opt/bgp-learning/
sudo chown -R bgplearning:bgplearning /opt/bgp-learning

# Frontend
sudo mkdir -p /var/www/bgp-learning
sudo cp -r /tmp/bgp-learning-site/frontend/* /var/www/bgp-learning/
sudo chown -R www-data:www-data /var/www/bgp-learning
```

### Шаг 7: Создание systemd сервиса
```bash
sudo tee /etc/systemd/system/bgp-learning.service > /dev/null << 'EOF'
[Unit]
Description=BGP Learning Platform
After=network.target

[Service]
Type=exec
User=bgplearning
Group=bgplearning
WorkingDirectory=/opt/bgp-learning
Environment=PATH=/opt/bgp-learning/venv/bin
ExecStart=/opt/bgp-learning/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 3 app:app
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=3

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/bgp-learning

LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable bgp-learning
```

### Шаг 8: Настройка Nginx
```bash
sudo tee /etc/nginx/sites-available/bgp-learning > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;
    
    access_log /var/log/nginx/bgp-learning-access.log;
    error_log /var/log/nginx/bgp-learning-error.log;
    
    location / {
        root /var/www/bgp-learning;
        index index.html;
        try_files $uri $uri/ =404;
    }
    
    location /api/ {
        proxy_pass http://127.0.0.1:5000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
        root /var/www/bgp-learning;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
}
EOF

sudo ln -sf /etc/nginx/sites-available/bgp-learning /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
```

### Шаг 9: Настройка брандмауэра
```bash
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
```

### Шаг 10: Настройка логирования
```bash
sudo tee /etc/logrotate.d/bgp-learning > /dev/null << 'EOF'
/var/log/bgp-learning/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 bgplearning bgplearning
    postrotate
        systemctl reload bgp-learning
    endscript
}
EOF

sudo touch /var/log/bgp-learning.log
sudo chown syslog:adm /var/log/bgp-learning.log
```

### Шаг 11: Запуск сервисов
```bash
sudo systemctl start bgp-learning
sudo systemctl restart nginx
```

</details>

---

## 🎯 Использование платформы

### Доступ к сайту

- **HTTP**: `http://IP-вашего-сервера/` или `http://ваш-домен/`
- **HTTPS** (если настроен SSL): `https://ваш-домен/`

### Первый урок: Установление BGP соседства

1. **Откройте браузер** и перейдите на `http://IP-сервера/`

2. **Выберите маршрутизатор R1** в селекторе

3. **Введите команды по порядку:**
   ```
   neighbor 192.168.1.2 remote-as 65002
   neighbor 192.168.1.2 activate
   ```

4. **Используйте кнопку "Следующий шаг"** для просмотра процесса установления BGP соседства

5. **Наблюдайте за:**
   - Анимацией BGP пакетов между роутерами
   - Изменением состояний BGP (Idle → OpenSent → Established)
   - Подсветкой активного соединения

### Поддерживаемые команды
- `neighbor IP remote-as AS` - настройка BGP соседа
- `neighbor IP activate` - активация BGP соседа

---

## 🔧 Управление системой

### Основные команды
```bash
# Статус сервисов
sudo systemctl status bgp-learning
sudo systemctl status nginx

# Перезапуск
sudo systemctl restart bgp-learning
sudo systemctl restart nginx

# Просмотр логов
sudo journalctl -u bgp-learning -f
sudo tail -f /var/log/nginx/bgp-learning-error.log

# Общая диагностика
/usr/local/bin/bgp-learning-status
```

### Обновление приложения
```bash
# После загрузки новой версии файлов
sudo chmod +x scripts/update.sh
sudo ./scripts/update.sh
```

### SSL сертификаты

**Самоподписанный сертификат:**
- Быстрая настройка для тестирования
- Браузеры будут показывать предупреждение о безопасности
- Нужно добавить исключение в браузере

**Let's Encrypt сертификат:**
- Бесплатный доверенный сертификат
- Требует настроенный DNS (домен должен указывать на сервер)
- Автоматическое обновление через cron
- Рекомендуется для продакшена

---

## 🚨 Устранение проблем

### Проблема: Сервис не запускается
```bash
# Проверка статуса
sudo systemctl status bgp-learning --no-pager -l

# Просмотр логов
sudo journalctl -u bgp-learning -n 50 --no-pager

# Проверка файлов
ls -la /opt/bgp-learning/
```

### Проблема: Nginx возвращает 502 ошибку
```bash
# Проверка доступности API
curl http://127.0.0.1:5000/api/lessons/first

# Проверка портов
sudo netstat -tlnp | grep 5000

# Перезапуск сервисов
sudo systemctl restart bgp-learning nginx
```

### Проблема: Веб-интерфейс недоступен
```bash
# Проверка Nginx
sudo nginx -t
sudo systemctl status nginx

# Проверка файлов frontend
ls -la /var/www/bgp-learning/

# Проверка прав доступа
sudo chown -R www-data:www-data /var/www/bgp-learning
```

### Проблема: Не работает брандмауэр
```bash
# Проверка UFW
sudo ufw status

# Добавление правил
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

---

## 🔒 Безопасность

### Для продакшн использования:

1. **Настройте HTTPS:**
   ```bash
   sudo certbot --nginx -d your-domain.com
   ```

2. **Обновите систему:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

3. **Мониторьте логи:**
   ```bash
   sudo tail -f /var/log/nginx/bgp-learning-access.log
   ```

4. **Настройте резервное копирование:**
   ```bash
   # Создание backup
   sudo tar -czf bgp-learning-backup-$(date +%Y%m%d).tar.gz \
     /opt/bgp-learning /var/www/bgp-learning /etc/nginx/sites-available/bgp-learning
   ```

---

## 📊 Мониторинг

### Доступные метрики
- Статус systemd сервисов
- Использование CPU и памяти
- Логи ошибок Nginx
- Состояние портов 80 и 5000

### Скрипт мониторинга
```bash
/usr/local/bin/bgp-learning-status
```

---

## 🎉 Готово!

После успешной установки у вас будет работающая платформа BGP Learning, доступная по адресу вашего сервера. Пользователи смогут изучать BGP в интерактивном режиме с визуальной симуляцией процессов.

**Основные возможности MVP:**
- ✅ Визуальная симуляция BGP соседства
- ✅ Пошаговое выполнение команд
- ✅ Анимация BGP пакетов
- ✅ Интуитивный веб-интерфейс
- ✅ Автоматическая установка и настройка
- ✅ Полное логирование и мониторинг
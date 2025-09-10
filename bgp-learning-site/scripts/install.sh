#!/bin/bash

# Скрипт автоматической установки и настройки BGP Learning Platform на Ubuntu 22.04
# Автор: BGP Learning Team
# Версия: 1.0

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции вывода
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

# Проверка прав администратора
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Этот скрипт должен быть запущен с правами root (sudo)"
        exit 1
    fi
}

# Обновление системы
update_system() {
    info "Обновление системы..."
    apt update && apt upgrade -y
    success "Система обновлена"
}

# Установка зависимостей
install_dependencies() {
    info "Установка зависимостей..."
    
    # Основные пакеты
    apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        nginx \
        git \
        curl \
        unzip \
        ufw \
        certbot \
        python3-certbot-nginx
    
    success "Зависимости установлены"
}

# Создание пользователя для приложения
create_app_user() {
    info "Создание пользователя приложения..."
    
    if ! id "bgplearning" &>/dev/null; then
        useradd -r -s /bin/false -d /opt/bgp-learning bgplearning
        success "Пользователь bgplearning создан"
    else
        warning "Пользователь bgplearning уже существует"
    fi
}

# Создание директорий
setup_directories() {
    info "Создание директорий..."
    
    # Основные директории
    mkdir -p /opt/bgp-learning
    mkdir -p /var/log/bgp-learning
    mkdir -p /etc/bgp-learning
    
    # Права доступа
    chown -R bgplearning:bgplearning /opt/bgp-learning
    chown -R bgplearning:bgplearning /var/log/bgp-learning
    chmod 755 /opt/bgp-learning
    chmod 755 /var/log/bgp-learning
    
    success "Директории созданы"
}

# Установка приложения
install_application() {
    info "Установка приложения..."
    
    # Переход в директорию приложения
    cd /opt/bgp-learning
    
    # Создание виртуального окружения
    python3 -m venv venv
    source venv/bin/activate
    
    # Обновление pip
    pip install --upgrade pip
    
    # Установка зависимостей Python
    pip install flask flask-cors gunicorn
    
    success "Приложение установлено"
}

# Копирование файлов приложения
copy_application_files() {
    info "Копирование файлов приложения..."
    
    # Определение исходной директории
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SOURCE_DIR="$(dirname "$SCRIPT_DIR")"
    
    # Копирование backend
    cp -r "$SOURCE_DIR/backend"/* /opt/bgp-learning/
    
    # Копирование frontend
    mkdir -p /var/www/bgp-learning
    cp -r "$SOURCE_DIR/frontend"/* /var/www/bgp-learning/
    
    # Установка прав
    chown -R bgplearning:bgplearning /opt/bgp-learning
    chown -R www-data:www-data /var/www/bgp-learning
    
    success "Файлы приложения скопированы"
}

# Создание systemd сервиса
create_systemd_service() {
    info "Создание systemd сервиса..."
    
    cat > /etc/systemd/system/bgp-learning.service << 'EOF'
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

# Безопасность
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/bgp-learning

# Ограничения ресурсов
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

    # Обновление systemd и запуск сервиса
    systemctl daemon-reload
    systemctl enable bgp-learning
    
    success "Systemd сервис создан"
}

# Настройка Nginx
configure_nginx() {
    info "Настройка Nginx..."
    
    # Создание конфигурации сайта
    cat > /etc/nginx/sites-available/bgp-learning << 'EOF'
server {
    listen 80;
    server_name _;
    
    # Логирование
    access_log /var/log/nginx/bgp-learning-access.log;
    error_log /var/log/nginx/bgp-learning-error.log;
    
    # Основной сайт
    location / {
        root /var/www/bgp-learning;
        index index.html;
        try_files $uri $uri/ =404;
    }
    
    # API проксирование
    location /api/ {
        proxy_pass http://127.0.0.1:5000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Статические файлы с кешированием
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
        root /var/www/bgp-learning;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Безопасность
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
}
EOF

    # Активация сайта
    ln -sf /etc/nginx/sites-available/bgp-learning /etc/nginx/sites-enabled/
    
    # Удаление дефолтного сайта
    rm -f /etc/nginx/sites-enabled/default
    
    # Проверка конфигурации
    nginx -t
    
    success "Nginx настроен"
}

# Настройка логирования
setup_logging() {
    info "Настройка логирования..."
    
    # Конфигурация logrotate
    cat > /etc/logrotate.d/bgp-learning << 'EOF'
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

    # Создание файла логов
    touch /var/log/bgp-learning.log
    chown syslog:adm /var/log/bgp-learning.log
    chmod 644 /var/log/bgp-learning.log
    
    success "Логирование настроено"
}

# Настройка брандмауэра
configure_firewall() {
    info "Настройка брандмауэра..."
    
    # Основные правила UFW
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Разрешение SSH
    ufw allow ssh
    
    # Разрешение HTTP и HTTPS
    ufw allow 'Nginx Full'
    
    # Включение UFW
    ufw --force enable
    
    success "Брандмауэр настроен"
}

# Создание скрипта мониторинга
create_monitoring_script() {
    info "Создание скрипта мониторинга..."
    
    cat > /usr/local/bin/bgp-learning-status << 'EOF'
#!/bin/bash

# Скрипт проверки состояния BGP Learning Platform

echo "=== BGP Learning Platform Status ==="
echo

# Проверка сервиса
echo "Service Status:"
systemctl is-active --quiet bgp-learning && echo "✓ BGP Learning service is running" || echo "✗ BGP Learning service is not running"

# Проверка Nginx
systemctl is-active --quiet nginx && echo "✓ Nginx is running" || echo "✗ Nginx is not running"

# Проверка портов
echo
echo "Port Status:"
ss -tlnp | grep :80 > /dev/null && echo "✓ HTTP port 80 is open" || echo "✗ HTTP port 80 is not open"
ss -tlnp | grep :5000 > /dev/null && echo "✓ API port 5000 is open" || echo "✗ API port 5000 is not open"

# Проверка логов
echo
echo "Recent Logs:"
echo "--- Application Logs ---"
tail -n 5 /var/log/bgp-learning.log 2>/dev/null || echo "No application logs found"
echo
echo "--- Nginx Error Logs ---"
tail -n 5 /var/log/nginx/bgp-learning-error.log 2>/dev/null || echo "No nginx error logs found"

# Использование ресурсов
echo
echo "Resource Usage:"
echo "Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
EOF

    chmod +x /usr/local/bin/bgp-learning-status
    
    success "Скрипт мониторинга создан"
}

# Запуск сервисов
start_services() {
    info "Запуск сервисов..."
    
    # Запуск BGP Learning
    systemctl start bgp-learning
    
    # Перезапуск Nginx
    systemctl restart nginx
    
    # Проверка статуса
    sleep 3
    
    if systemctl is-active --quiet bgp-learning; then
        success "BGP Learning сервис запущен"
    else
        error "Ошибка запуска BGP Learning сервиса"
        systemctl status bgp-learning
        exit 1
    fi
    
    if systemctl is-active --quiet nginx; then
        success "Nginx запущен"
    else
        error "Ошибка запуска Nginx"
        systemctl status nginx
        exit 1
    fi
}

# Финальная проверка
final_check() {
    info "Финальная проверка..."
    
    # Проверка HTTP ответа
    sleep 5
    if curl -f -s http://localhost/ > /dev/null; then
        success "Веб-интерфейс доступен"
    else
        warning "Веб-интерфейс может быть недоступен"
    fi
    
    # Проверка API
    if curl -f -s http://localhost/api/lessons/first > /dev/null; then
        success "API доступен"
    else
        warning "API может быть недоступен"
    fi
}

# Вывод финальной информации
show_final_info() {
    echo
    echo "================================="
    success "Установка BGP Learning Platform завершена!"
    echo "================================="
    echo
    info "Полезная информация:"
    echo "• Веб-интерфейс: http://$(hostname -I | awk '{print $1}')/"
    echo "• Логи приложения: /var/log/bgp-learning.log"
    echo "• Логи Nginx: /var/log/nginx/bgp-learning-*.log"
    echo "• Статус сервисов: /usr/local/bin/bgp-learning-status"
    echo
    info "Управление сервисами:"
    echo "• Перезапуск BGP Learning: sudo systemctl restart bgp-learning"
    echo "• Перезапуск Nginx: sudo systemctl restart nginx"
    echo "• Просмотр логов: sudo journalctl -u bgp-learning -f"
    echo
    warning "Не забудьте:"
    echo "• Настроить DNS для вашего домена"
    echo "• Установить SSL сертификат (certbot)"
    echo "• Регулярно обновлять систему"
    echo
}

# Основная функция установки
main() {
    echo "BGP Learning Platform Installer for Ubuntu 22.04"
    echo "================================================"
    echo
    
    check_root
    update_system
    install_dependencies
    create_app_user
    setup_directories
    install_application
    copy_application_files
    create_systemd_service
    configure_nginx
    setup_logging
    configure_firewall
    create_monitoring_script
    start_services
    final_check
    show_final_info
}

# Запуск установки
main "$@"
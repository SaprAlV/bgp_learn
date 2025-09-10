#!/bin/bash

# Скрипт автоматической установки и настройки BGP Learning Platform на Ubuntu 22.04
# Автор: BGP Learning Team
# Версия: 1.1

set -e

# Переменные конфигурации
DOMAIN_NAME=""
CREATE_SSL="false"
SSL_TYPE="none"

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
    
    # Альтернативные пути для поиска исходных файлов
    POSSIBLE_SOURCES=(
        "$SOURCE_DIR"
        "$(pwd)"
        "/tmp/bgp-learning-site"
        "/var/project/bgp_learn/bgp-learning-site"
        "$(dirname "$(pwd)")"
    )
    
    # Поиск правильного пути к исходным файлам
    FOUND_SOURCE=""
    for source_path in "${POSSIBLE_SOURCES[@]}"; do
        if [[ -d "$source_path/backend" && -d "$source_path/frontend" ]]; then
            FOUND_SOURCE="$source_path"
            info "Найдены исходные файлы в: $FOUND_SOURCE"
            break
        fi
    done
    
    if [[ -z "$FOUND_SOURCE" ]]; then
        error "Не удалось найти исходные файлы (backend и frontend директории)"
        error "Проверьте, что скрипт запускается из корневой директории проекта"
        error "Или что файлы находятся в одной из следующих локаций:"
        for source_path in "${POSSIBLE_SOURCES[@]}"; do
            error "  - $source_path"
        done
        exit 1
    fi
    
    # Копирование backend
    info "Копирование backend из: $FOUND_SOURCE/backend"
    cp -r "$FOUND_SOURCE/backend"/* /opt/bgp-learning/
    
    # Копирование frontend
    mkdir -p /var/www/bgp-learning
    info "Копирование frontend из: $FOUND_SOURCE/frontend"
    cp -r "$FOUND_SOURCE/frontend"/* /var/www/bgp-learning/
    
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
    update_final_info
    
    echo
    echo "================================="
    success "Установка BGP Learning Platform завершена!"
    echo "================================="
    echo
    info "Конфигурация:"
    echo "• Доменное имя: $DOMAIN_NAME"
    echo "• SSL сертификат: $([[ "$CREATE_SSL" == "true" ]] && echo "включен ($SSL_TYPE)" || echo "отключен")"
    echo
    info "Доступ к платформе:"
    echo "• Веб-интерфейс: $FINAL_URL"
    if [[ "$CREATE_SSL" == "true" && "$SSL_TYPE" == "self-signed" ]]; then
        warning "Самоподписанный сертификат - браузер покажет предупреждение"
        echo "  Добавьте исключение в браузере для продолжения"
    fi
    echo
    info "Системная информация:"
    echo "• Логи приложения: /var/log/bgp-learning.log"
    echo "• Логи Nginx: /var/log/nginx/bgp-learning-*.log"
    echo "• Статус сервисов: /usr/local/bin/bgp-learning-status"
    if [[ "$CREATE_SSL" == "true" ]]; then
        echo "• SSL сертификаты: /etc/ssl/certs/bgp-learning.* или /etc/letsencrypt/live/$DOMAIN_NAME/"
    fi
    echo
    info "Управление сервисами:"
    echo "• Перезапуск BGP Learning: sudo systemctl restart bgp-learning"
    echo "• Перезапуск Nginx: sudo systemctl restart nginx"
    echo "• Просмотр логов: sudo journalctl -u bgp-learning -f"
    if [[ "$CREATE_SSL" == "true" && "$SSL_TYPE" == "letsencrypt" ]]; then
        echo "• Обновление SSL: sudo certbot renew"
    fi
    echo
    if [[ "$CREATE_SSL" != "true" ]]; then
        warning "Рекомендации для продакшена:"
        echo "• Настроить SSL сертификат для безопасности"
        echo "• Использовать: $0 -d $DOMAIN_NAME --ssl letsencrypt"
    fi
    warning "Не забудьте:"
    if [[ "$DOMAIN_NAME" != "_" ]]; then
        echo "• Убедиться, что DNS указывает на этот сервер"
    fi
    echo "• Регулярно обновлять систему"
    echo "• Мониторить логи на предмет ошибок"
    echo
}

# Функция обработки аргументов командной строки
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                DOMAIN_NAME="$2"
                shift 2
                ;;
            --ssl)
                CREATE_SSL="true"
                SSL_TYPE="$2"
                if [[ "$SSL_TYPE" != "self-signed" && "$SSL_TYPE" != "letsencrypt" ]]; then
                    error "SSL тип должен быть 'self-signed' или 'letsencrypt'"
                    exit 1
                fi
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error "Неизвестный параметр: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Функция показа справки
show_help() {
    echo "BGP Learning Platform Installer for Ubuntu 22.04"
    echo "================================================"
    echo
    echo "Использование: $0 [ОПЦИИ]"
    echo
    echo "Опции:"
    echo "  -d, --domain DOMAIN     Доменное имя для сайта (например: bgp.example.com)"
    echo "  --ssl TYPE              Создать SSL сертификат (self-signed|letsencrypt)"
    echo "  -h, --help              Показать эту справку"
    echo
    echo "Примеры:"
    echo "  $0                                    # Установка без SSL на localhost"
    echo "  $0 -d bgp.example.com                # Установка с доменом без SSL"
    echo "  $0 -d bgp.example.com --ssl self-signed   # С самоподписанным сертификатом"
    echo "  $0 -d bgp.example.com --ssl letsencrypt   # С Let's Encrypt сертификатом"
    echo
}

# Функция интерактивного ввода конфигурации
interactive_config() {
    if [[ -z "$DOMAIN_NAME" ]]; then
        echo
        read -p "Введите доменное имя (или нажмите Enter для localhost): " DOMAIN_NAME
        
        if [[ -n "$DOMAIN_NAME" && "$DOMAIN_NAME" != "localhost" ]]; then
            echo
            echo "Выберите тип SSL сертификата:"
            echo "1) Без SSL"
            echo "2) Самоподписанный сертификат"
            echo "3) Let's Encrypt (требует настроенный DNS)"
            echo
            read -p "Ваш выбор (1-3): " ssl_choice
            
            case $ssl_choice in
                2)
                    CREATE_SSL="true"
                    SSL_TYPE="self-signed"
                    ;;
                3)
                    CREATE_SSL="true"
                    SSL_TYPE="letsencrypt"
                    ;;
                *)
                    CREATE_SSL="false"
                    SSL_TYPE="none"
                    ;;
            esac
        fi
    fi
    
    # Установка значений по умолчанию
    if [[ -z "$DOMAIN_NAME" ]]; then
        DOMAIN_NAME="_"
    fi
}

# Основная функция установки
main() {
    echo "BGP Learning Platform Installer for Ubuntu 22.04"
    echo "================================================"
    echo
    
    parse_arguments "$@"
    interactive_config
    
    # Показ конфигурации
    echo
    info "Конфигурация установки:"
    echo "• Доменное имя: $DOMAIN_NAME"
    echo "• SSL сертификат: $([[ "$CREATE_SSL" == "true" ]] && echo "$SSL_TYPE" || echo "отключен")"
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
    setup_ssl_certificates
    setup_logging
    configure_firewall
    create_monitoring_script
    start_services
    final_check
    show_final_info
}

# Настройка SSL сертификатов
setup_ssl_certificates() {
    if [[ "$CREATE_SSL" != "true" ]]; then
        info "SSL сертификаты не настраиваются"
        return 0
    fi
    
    info "Настройка SSL сертификатов ($SSL_TYPE)..."
    
    if [[ "$SSL_TYPE" == "self-signed" ]]; then
        create_self_signed_certificate
    elif [[ "$SSL_TYPE" == "letsencrypt" ]]; then
        create_letsencrypt_certificate
    fi
}

# Создание самоподписанного сертификата
create_self_signed_certificate() {
    info "Создание самоподписанного SSL сертификата..."
    
    # Создание директорий для сертификатов
    mkdir -p /etc/ssl/certs /etc/ssl/private
    
    # Генерация приватного ключа
    openssl genrsa -out /etc/ssl/private/bgp-learning.key 2048
    
    # Создание конфигурационного файла для сертификата
    cat > /tmp/ssl.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = RU
ST = Moscow
L = Moscow
O = BGP Learning Platform
OU = IT Department
CN = $DOMAIN_NAME

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN_NAME
DNS.2 = www.$DOMAIN_NAME
IP.1 = 127.0.0.1
EOF
    
    # Генерация сертификата
    openssl req -new -x509 -key /etc/ssl/private/bgp-learning.key \
        -out /etc/ssl/certs/bgp-learning.crt -days 365 \
        -config /tmp/ssl.conf -extensions v3_req
    
    # Установка прав доступа
    chmod 600 /etc/ssl/private/bgp-learning.key
    chmod 644 /etc/ssl/certs/bgp-learning.crt
    
    # Удаление временного файла
    rm -f /tmp/ssl.conf
    
    success "Самоподписанный SSL сертификат создан"
    warning "Браузеры будут показывать предупреждение о безопасности"
}

# Создание Let's Encrypt сертификата
create_letsencrypt_certificate() {
    info "Создание Let's Encrypt SSL сертификата..."
    
    # Проверка доступности домена
    if ! ping -c 1 "$DOMAIN_NAME" > /dev/null 2>&1; then
        warning "Домен $DOMAIN_NAME недоступен. Убедитесь, что DNS настроен правильно."
        read -p "Продолжить создание сертификата? (y/N): " continue_cert
        if [[ "$continue_cert" != "y" && "$continue_cert" != "Y" ]]; then
            info "Пропуск создания Let's Encrypt сертификата"
            return 0
        fi
    fi
    
    # Временная конфигурация Nginx для проверки домена
    systemctl stop nginx || true
    
    # Создание Let's Encrypt сертификата
    if certbot certonly --standalone -d "$DOMAIN_NAME" --non-interactive --agree-tos \
        --email "admin@$DOMAIN_NAME" --preferred-challenges http; then
        
        # Обновление путей к сертификатам в конфигурации Nginx
        sed -i "s|/etc/ssl/certs/bgp-learning.crt|/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem|g" \
            /etc/nginx/sites-available/bgp-learning
        sed -i "s|/etc/ssl/private/bgp-learning.key|/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem|g" \
            /etc/nginx/sites-available/bgp-learning
        
        # Настройка автоматического обновления сертификата
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx") | crontab -
        
        success "Let's Encrypt SSL сертификат создан"
    else
        error "Ошибка создания Let's Encrypt сертификата"
        warning "Переключаемся на самоподписанный сертификат"
        create_self_signed_certificate
    fi
}

# Обновление информации о финальном результате
update_final_info() {
    local protocol="http"
    local port=""
    
    if [[ "$CREATE_SSL" == "true" ]]; then
        protocol="https"
    fi
    
    if [[ "$DOMAIN_NAME" == "_" ]]; then
        FINAL_URL="$protocol://$(hostname -I | awk '{print $1}')/"
    else
        FINAL_URL="$protocol://$DOMAIN_NAME/"
    fi
}

# Запуск установки
main "$@"
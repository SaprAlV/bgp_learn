#!/bin/bash

# Скрипт для настройки HTTPS в Nginx для BGP Learning Platform
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Параметры по умолчанию
DOMAIN_NAME="bgp.sapr.local"
CREATE_SSL="true"
SSL_TYPE="self-signed"

# Обработка аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAIN_NAME="$2"
            shift 2
            ;;
        --ssl)
            SSL_TYPE="$2"
            if [[ "$SSL_TYPE" != "self-signed" && "$SSL_TYPE" != "letsencrypt" ]]; then
                error "SSL тип должен быть 'self-signed' или 'letsencrypt'"
                exit 1
            fi
            shift 2
            ;;
        --no-ssl)
            CREATE_SSL="false"
            shift
            ;;
        -h|--help)
            echo "Использование: $0 [ОПЦИИ]"
            echo "Опции:"
            echo "  -d, --domain DOMAIN     Доменное имя (по умолчанию: bgp.sapr.local)"
            echo "  --ssl TYPE              Тип SSL сертификата (self-signed|letsencrypt)"
            echo "  --no-ssl               Отключить SSL"
            echo "  -h, --help             Показать эту справку"
            exit 0
            ;;
        *)
            error "Неизвестный параметр: $1"
            exit 1
            ;;
    esac
done

info "Настройка Nginx для домена: $DOMAIN_NAME"
info "SSL: $([[ "$CREATE_SSL" == "true" ]] && echo "включен ($SSL_TYPE)" || echo "отключен")"

# Остановка nginx
info "Остановка nginx..."
systemctl stop nginx

# Создание SSL сертификата если нужно
if [[ "$CREATE_SSL" == "true" ]]; then
    if [[ "$SSL_TYPE" == "self-signed" ]]; then
        info "Создание самоподписанного SSL сертификата..."
        
        # Создание директорий
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
        
    elif [[ "$SSL_TYPE" == "letsencrypt" ]]; then
        info "Создание Let's Encrypt сертификата..."
        
        # Проверка доступности домена
        if ! ping -c 1 "$DOMAIN_NAME" > /dev/null 2>&1; then
            warning "Домен $DOMAIN_NAME недоступен. Убедитесь, что DNS настроен правильно."
            read -p "Продолжить создание сертификата? (y/N): " continue_cert
            if [[ "$continue_cert" != "y" && "$continue_cert" != "Y" ]]; then
                info "Переключаемся на самоподписанный сертификат"
                SSL_TYPE="self-signed"
                # Рекурсивный вызов с self-signed
                exec "$0" -d "$DOMAIN_NAME" --ssl self-signed
            fi
        fi
        
        # Создание Let's Encrypt сертификата
        if certbot certonly --standalone -d "$DOMAIN_NAME" --non-interactive --agree-tos \
            --email "admin@$DOMAIN_NAME" --preferred-challenges http; then
            success "Let's Encrypt SSL сертификат создан"
            
            # Настройка автоматического обновления
            (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx") | crontab -
        else
            error "Ошибка создания Let's Encrypt сертификата"
            warning "Переключаемся на самоподписанный сертификат"
            SSL_TYPE="self-signed"
            # Рекурсивный вызов с self-signed
            exec "$0" -d "$DOMAIN_NAME" --ssl self-signed
        fi
    fi
fi

# Создание конфигурации Nginx
info "Создание конфигурации Nginx..."

if [[ "$CREATE_SSL" == "true" ]]; then
    # HTTPS конфигурация
    cert_path="/etc/ssl/certs/bgp-learning.crt"
    key_path="/etc/ssl/private/bgp-learning.key"
    
    if [[ "$SSL_TYPE" == "letsencrypt" ]]; then
        cert_path="/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem"
        key_path="/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem"
    fi
    
    cat > /etc/nginx/sites-available/bgp-learning << EOF
# HTTP сервер (редирект на HTTPS)
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    # Редирект на HTTPS
    return 301 https://\$server_name\$request_uri;
}

# HTTPS сервер
server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;
    
    # SSL сертификаты
    ssl_certificate $cert_path;
    ssl_certificate_key $key_path;
    
    # SSL настройки
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Логирование
    access_log /var/log/nginx/bgp-learning-access.log;
    error_log /var/log/nginx/bgp-learning-error.log;
    
    # Основной сайт
    location / {
        root /var/www/bgp-learning;
        index index.html;
        try_files \$uri \$uri/ =404;
    }
    
    # API проксирование
    location /api/ {
        proxy_pass http://127.0.0.1:5000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Статические файлы с кешированием
    location ~* \\.(css|js|png|jpg|jpeg|gif|ico|svg)\$ {
        root /var/www/bgp-learning;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Безопасность
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
EOF

else
    # HTTP только конфигурация
    cat > /etc/nginx/sites-available/bgp-learning << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    # Логирование
    access_log /var/log/nginx/bgp-learning-access.log;
    error_log /var/log/nginx/bgp-learning-error.log;
    
    # Основной сайт
    location / {
        root /var/www/bgp-learning;
        index index.html;
        try_files \$uri \$uri/ =404;
    }
    
    # API проксирование
    location /api/ {
        proxy_pass http://127.0.0.1:5000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Статические файлы с кешированием
    location ~* \\.(css|js|png|jpg|jpeg|gif|ico|svg)\$ {
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
fi

# Проверка конфигурации
info "Проверка конфигурации nginx..."
if nginx -t; then
    success "Конфигурация nginx корректна"
else
    error "Ошибка в конфигурации nginx"
    exit 1
fi

# Запуск nginx
info "Запуск nginx..."
systemctl start nginx

# Проверка статуса
if systemctl is-active --quiet nginx; then
    success "Nginx запущен успешно"
else
    error "Ошибка запуска nginx"
    systemctl status nginx
    exit 1
fi

# Тестирование
info "Тестирование доступности..."

if [[ "$CREATE_SSL" == "true" ]]; then
    protocol="https"
    port_info="(HTTPS)"
else
    protocol="http"  
    port_info="(HTTP)"
fi

url="$protocol://$DOMAIN_NAME/"

sleep 2
if curl -k -s "$url" > /dev/null; then
    success "Сайт доступен: $url"
else
    warning "Сайт может быть недоступен по адресу: $url"
fi

# Финальная информация
echo
echo "================================="
success "Nginx настроен успешно!"
echo "================================="
echo
info "Конфигурация:"
echo "• Домен: $DOMAIN_NAME"
echo "• SSL: $([[ "$CREATE_SSL" == "true" ]] && echo "включен ($SSL_TYPE)" || echo "отключен")"
echo "• URL: $url"
echo
info "Доступ:"
echo "• Веб-интерфейс: $url"
if [[ "$CREATE_SSL" == "true" && "$SSL_TYPE" == "self-signed" ]]; then
    warning "Самоподписанный сертификат - браузер покажет предупреждение"
    echo "  Добавьте исключение в браузере для продолжения"
fi
echo
info "Управление:"
echo "• Перезапуск nginx: sudo systemctl restart nginx"
echo "• Статус nginx: sudo systemctl status nginx"
echo "• Логи nginx: sudo tail -f /var/log/nginx/bgp-learning-error.log"
if [[ "$CREATE_SSL" == "true" && "$SSL_TYPE" == "letsencrypt" ]]; then
    echo "• Обновление SSL: sudo certbot renew"
fi
echo
#!/bin/bash

# Скрипт обновления BGP Learning Platform
# Использовать для обновления кода без переустановки системы

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

# Проверка прав администратора
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Этот скрипт должен быть запущен с правами root (sudo)"
        exit 1
    fi
}

# Создание резервной копии
create_backup() {
    info "Создание резервной копии..."
    
    BACKUP_DIR="/opt/bgp-learning-backup-$(date +%Y%m%d-%H%M%S)"
    
    # Бэкап backend
    cp -r /opt/bgp-learning "$BACKUP_DIR"
    
    # Бэкап frontend
    mkdir -p "$BACKUP_DIR/frontend"
    cp -r /var/www/bgp-learning/* "$BACKUP_DIR/frontend/"
    
    success "Резервная копия создана: $BACKUP_DIR"
}

# Остановка сервисов
stop_services() {
    info "Остановка сервисов..."
    
    systemctl stop bgp-learning
    success "Сервисы остановлены"
}

# Обновление кода
update_code() {
    info "Обновление кода приложения..."
    
    # Определение исходной директории
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SOURCE_DIR="$(dirname "$SCRIPT_DIR")"
    
    # Обновление backend
    cp -r "$SOURCE_DIR/backend"/* /opt/bgp-learning/
    
    # Обновление frontend
    cp -r "$SOURCE_DIR/frontend"/* /var/www/bgp-learning/
    
    # Восстановление прав
    chown -R bgplearning:bgplearning /opt/bgp-learning
    chown -R www-data:www-data /var/www/bgp-learning
    
    success "Код обновлен"
}

# Обновление зависимостей
update_dependencies() {
    info "Обновление зависимостей..."
    
    cd /opt/bgp-learning
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt --upgrade
    
    success "Зависимости обновлены"
}

# Запуск сервисов
start_services() {
    info "Запуск сервисов..."
    
    systemctl start bgp-learning
    systemctl reload nginx
    
    # Проверка статуса
    sleep 3
    
    if systemctl is-active --quiet bgp-learning; then
        success "BGP Learning сервис запущен"
    else
        error "Ошибка запуска BGP Learning сервиса"
        systemctl status bgp-learning
        exit 1
    fi
}

# Проверка работоспособности
health_check() {
    info "Проверка работоспособности..."
    
    sleep 5
    
    # Проверка веб-интерфейса
    if curl -f -s http://localhost/ > /dev/null; then
        success "Веб-интерфейс доступен"
    else
        error "Веб-интерфейс недоступен"
        exit 1
    fi
    
    # Проверка API
    if curl -f -s http://localhost/api/lessons/first > /dev/null; then
        success "API доступен"
    else
        error "API недоступен"
        exit 1
    fi
}

# Основная функция
main() {
    echo "BGP Learning Platform Updater"
    echo "============================"
    echo
    
    check_root
    create_backup
    stop_services
    update_code
    update_dependencies
    start_services
    health_check
    
    echo
    success "Обновление BGP Learning Platform завершено успешно!"
    echo
    info "Для проверки статуса используйте: /usr/local/bin/bgp-learning-status"
}

main "$@"
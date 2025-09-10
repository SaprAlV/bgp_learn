# BGP Learning Platform

Интерактивная платформа для изучения протокола BGP, вдохновленная learngitbranching.

## Описание

BGP Learning Platform - это веб-приложение, которое позволяет пользователям изучать протокол BGP в интерактивном режиме. Платформа включает:

- **Визуальную симуляцию** установления BGP соседства
- **Пошаговое выполнение** команд с анимацией
- **Реалистичное моделирование** BGP процессов
- **Интуитивный интерфейс** с командной строкой и визуализацией

## Архитектура

```
BGP Learning Platform
├── Frontend (Vanilla JS/HTML/CSS)
│   ├── Интерфейс ввода команд
│   ├── Визуализация топологии сети
│   └── Анимация BGP пакетов
│
├── Backend (Python Flask)
│   ├── API для обработки команд
│   ├── Симуляция BGP процессов
│   └── Пошаговое выполнение
│
└── Deployment (Ubuntu 22.04)
    ├── Nginx (веб-сервер + проксирование API)
    ├── Systemd (управление сервисами)
    └── UFW (брандмауэр)
```

## Возможности

### Урок 1: Установление BGP соседства
- Настройка BGP соседей между двумя маршрутизаторами
- Команды: `neighbor IP remote-as AS`, `neighbor IP activate`
- Визуализация состояний BGP: Idle → OpenSent → Established
- Анимация BGP пакетов (OPEN, KEEPALIVE)

### Интерфейс
- **Левая панель**: инструкции, командная строка, управление симуляцией
- **Правая панель**: топология сети, состояние маршрутизаторов
- **Пошаговое выполнение**: кнопки "Следующий шаг", "Пауза", "Сброс"

## Быстрый старт

### Системные требования
- Ubuntu 22.04 LTS
- 2 GB RAM
- 10 GB свободного места
- Root доступ

### Автоматическая установка

1. **Скачайте проект**:
```bash
git clone <repository-url>
cd bgp-learning-site
```

2. **Запустите установку**:
```bash
sudo chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

3. **Откройте в браузере**:
```
http://your-server-ip/
```

### Ручная установка

<details>
<summary>Развернуть инструкции по ручной установке</summary>

#### 1. Установка зависимостей
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv nginx git curl ufw
```

#### 2. Создание пользователя
```bash
sudo useradd -r -s /bin/false -d /opt/bgp-learning bgplearning
sudo mkdir -p /opt/bgp-learning /var/log/bgp-learning
sudo chown -R bgplearning:bgplearning /opt/bgp-learning /var/log/bgp-learning
```

#### 3. Установка приложения
```bash
cd /opt/bgp-learning
sudo -u bgplearning python3 -m venv venv
sudo -u bgplearning venv/bin/pip install flask flask-cors gunicorn

# Копирование файлов
sudo cp backend/* /opt/bgp-learning/
sudo mkdir -p /var/www/bgp-learning
sudo cp frontend/* /var/www/bgp-learning/
sudo chown -R www-data:www-data /var/www/bgp-learning
```

#### 4. Настройка systemd
```bash
sudo cp scripts/bgp-learning.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable bgp-learning
sudo systemctl start bgp-learning
```

#### 5. Настройка Nginx
```bash
sudo cp scripts/nginx-bgp-learning.conf /etc/nginx/sites-available/bgp-learning
sudo ln -s /etc/nginx/sites-available/bgp-learning /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

#### 6. Настройка брандмауэра
```bash
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
```

</details>

## Управление

### Команды управления
```bash
# Статус сервисов
sudo systemctl status bgp-learning
sudo systemctl status nginx

# Перезапуск
sudo systemctl restart bgp-learning
sudo systemctl restart nginx

# Логи
sudo journalctl -u bgp-learning -f
sudo tail -f /var/log/nginx/bgp-learning-error.log

# Мониторинг
/usr/local/bin/bgp-learning-status
```

### Обновление
```bash
sudo ./scripts/update.sh
```

## Использование

### Первый урок

1. **Откройте веб-интерфейс** в браузере
2. **Выберите маршрутизатор** R1 в селекторе
3. **Введите команду**: `neighbor 192.168.1.2 remote-as 65002`
4. **Нажмите "Выполнить"**
5. **Введите команду**: `neighbor 192.168.1.2 activate`
6. **Используйте кнопку "Следующий шаг"** для просмотра процесса установления соседства

### Поддерживаемые команды
- `neighbor IP remote-as AS` - настройка BGP соседа
- `neighbor IP activate` - активация BGP соседа

## Архитектура кода

### Backend (Flask API)
```python
/api/simulation/reset     # Сброс симуляции
/api/simulation/state     # Получение состояния
/api/command/execute      # Выполнение команд
/api/simulation/step      # Пошаговое выполнение
/api/lessons/first        # Данные первого урока
```

### Frontend (JavaScript)
- `BGPLearningApp` - основной класс приложения
- Визуализация маршрутизаторов и анимация пакетов
- Управление состоянием симуляции
- Интерфейс командной строки

### Логирование
- **Приложение**: `/var/log/bgp-learning.log`
- **Nginx доступ**: `/var/log/nginx/bgp-learning-access.log`
- **Nginx ошибки**: `/var/log/nginx/bgp-learning-error.log`
- **Systemd**: `journalctl -u bgp-learning`

## Безопасность

### Реализованные меры
- Запуск приложения от непривилегированного пользователя
- UFW брандмауэр с минимальными правилами
- Nginx security headers
- Изоляция процессов через systemd
- Ограничения ресурсов

### Рекомендации
- Используйте HTTPS в продакшене
- Регулярно обновляйте систему
- Мониторьте логи на предмет подозрительной активности
- Настройте fail2ban для защиты от брутфорса

## Мониторинг

### Скрипт проверки состояния
```bash
/usr/local/bin/bgp-learning-status
```

### Метрики для мониторинга
- Статус systemd сервисов
- Открытые порты (80, 5000)
- Использование CPU и памяти
- Дисковое пространство
- Ошибки в логах

## Разработка

### Локальная разработка
```bash
# Backend
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py

# Frontend (в отдельном терминале)
cd frontend
python3 -m http.server 8000
```

### Структура проекта
```
bgp-learning-site/
├── backend/
│   ├── app.py              # Flask приложение
│   └── requirements.txt    # Python зависимости
├── frontend/
│   ├── index.html          # Главная страница
│   ├── style.css          # Стили
│   └── script.js          # JavaScript логика
├── scripts/
│   ├── install.sh         # Скрипт установки
│   └── update.sh          # Скрипт обновления
└── README.md              # Документация
```

## Устранение проблем

### Частые проблемы

**Сервис не запускается**
```bash
sudo systemctl status bgp-learning
sudo journalctl -u bgp-learning -n 50
```

**Nginx ошибки**
```bash
sudo nginx -t
sudo tail -f /var/log/nginx/bgp-learning-error.log
```

**API недоступен**
```bash
curl http://localhost:5000/api/lessons/first
netstat -tlnp | grep 5000
```

**Права доступа**
```bash
sudo chown -R bgplearning:bgplearning /opt/bgp-learning
sudo chown -R www-data:www-data /var/www/bgp-learning
```

## Лицензия

MIT License - см. файл LICENSE

## Поддержка

Для получения поддержки создайте issue в репозитории проекта.

## Планы развития

- [ ] Добавление новых уроков (Route Reflector, MPLS)
- [ ] Поддержка IPv6
- [ ] Экспорт/импорт конфигураций
- [ ] Система достижений
- [ ] Многопользовательский режим
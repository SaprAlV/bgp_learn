# 🚀 Быстрая установка BGP Learning Platform

## ✅ Исправлены проблемы

- **Исправлена ошибка копирования файлов** - добавлена проверка путей
- **Добавлена поддержка доменных имен** и SSL сертификатов
- **Поддержка самоподписанных** и **Let's Encrypt** сертификатов
- **Интерактивная настройка** при запуске без параметров

## 📋 Системные требования

- Ubuntu 22.04 LTS
- 2 GB RAM, 10 GB диск
- Root доступ (sudo)
- Интернет для загрузки пакетов

## 🔧 Установка

### 1. Подготовка файлов

Скопируйте папку `bgp-learning-site` на Ubuntu сервер:

```bash
# Через SCP
scp -r "путь/к/bgp-learning-site" user@server:/tmp/

# Или через Git
git clone <ваш-репозиторий>
```

### 2. Запуск установки

```bash
cd /tmp/bgp-learning-site
sudo chmod +x scripts/install.sh

# Варианты установки:

# 1. Простая установка (интерактивная настройка)
sudo ./scripts/install.sh

# 2. Установка без SSL на localhost
sudo ./scripts/install.sh

# 3. Установка с доменом без SSL
sudo ./scripts/install.sh -d bgp.example.com

# 4. Установка с самоподписанным SSL
sudo ./scripts/install.sh -d bgp.example.com --ssl self-signed

# 5. Установка с Let's Encrypt SSL (требует настроенный DNS)
sudo ./scripts/install.sh -d bgp.example.com --ssl letsencrypt

# Справка по параметрам
sudo ./scripts/install.sh --help
```

### 3. Проверка установки

```bash
# Статус сервисов
sudo systemctl status bgp-learning nginx

# Полная диагностика
/usr/local/bin/bgp-learning-status

# Проверка доступности
curl http://localhost/
curl http://localhost/api/lessons/first
```

## 🌐 Доступ к платформе

- **HTTP**: `http://IP-сервера/` или `http://ваш-домен/`
- **HTTPS**: `https://ваш-домен/` (при наличии SSL)

## 🎯 Использование

1. Откройте веб-интерфейс в браузере
2. Выберите маршрутизатор R1
3. Введите команды:
   ```
   neighbor 192.168.1.2 remote-as 65002
   neighbor 192.168.1.2 activate
   ```
4. Используйте кнопку "Следующий шаг" для просмотра процесса

## 🔧 Управление

```bash
# Перезапуск сервисов
sudo systemctl restart bgp-learning
sudo systemctl restart nginx

# Просмотр логов
sudo journalctl -u bgp-learning -f
sudo tail -f /var/log/nginx/bgp-learning-error.log

# Обновление приложения
sudo ./scripts/update.sh

# Мониторинг системы
/usr/local/bin/bgp-learning-status
```

## 🚨 Устранение проблем

### Сервис не запускается
```bash
sudo systemctl status bgp-learning --no-pager -l
sudo journalctl -u bgp-learning -n 50
```

### Nginx ошибки
```bash
sudo nginx -t
sudo systemctl restart nginx
```

### API недоступен
```bash
curl http://127.0.0.1:5000/api/lessons/first
sudo netstat -tlnp | grep 5000
```

### SSL проблемы
```bash
# Проверка сертификатов
sudo ls -la /etc/ssl/certs/bgp-learning.*
sudo ls -la /etc/letsencrypt/live/

# Пересоздание самоподписанного сертификата
sudo openssl req -new -x509 -days 365 -nodes \
  -out /etc/ssl/certs/bgp-learning.crt \
  -keyout /etc/ssl/private/bgp-learning.key
```

## 🔒 Безопасность

### Для продакшена:
- Используйте Let's Encrypt SSL
- Настройте регулярные обновления
- Мониторьте логи
- Настройте резервное копирование

### Брандмауэр настроен автоматически:
- SSH (порт 22)
- HTTP (порт 80)  
- HTTPS (порт 443)

## 📊 Возможности MVP

✅ **Реализовано:**
- Визуальная симуляция BGP соседства между 2 роутерами
- Поддержка команд `neighbor` и `activate`
- Пошаговое выполнение с анимацией пакетов
- Веб-интерфейс с командной строкой
- Автоматическая установка и настройка
- SSL поддержка (самоподписанный/Let's Encrypt)
- Полное логирование и мониторинг

✅ **Готово к использованию:**
- Обучение процессу установления BGP соседства
- Интерактивная визуализация сетевых процессов
- Простое развертывание на Ubuntu сервере

## 🎉 Результат

После успешной установки у вас будет полностью функциональная платформа для изучения BGP, доступная через веб-браузер с поддержкой HTTPS и всеми необходимыми инструментами для администрирования.

---

**Контакты:** Создайте issue в репозитории для получения поддержки.
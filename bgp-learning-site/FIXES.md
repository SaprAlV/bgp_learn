# 🔧 Исправления проблем установки

## ✅ Исправленная проблема

**Ошибка**: `./scripts/install.sh: line 123: cd: ./scripts: No such file or directory`

**Причина**: Скрипт не мог правильно определить путь к исходным файлам (backend и frontend директории).

**Решение**: Добавлена умная система поиска исходных файлов в нескольких возможных локациях.

## 🚀 Обновленный скрипт установки

Теперь скрипт автоматически ищет файлы в следующих местах:
1. Относительно своего расположения (стандартный случай)
2. В текущей рабочей директории
3. В `/tmp/bgp-learning-site`
4. В `/var/project/bgp_learn/bgp-learning-site` (ваш случай)
5. В родительской директории от текущей

## 📋 Инструкция по установке

### После исправления запустите:

```bash
cd /var/project/bgp_learn/bgp-learning-site
sudo ./scripts/install.sh -d bgp.sapr.local --ssl self-signed
```

### Альтернативные варианты:

```bash
# 1. Простая установка без SSL
sudo ./scripts/install.sh

# 2. С доменом без SSL  
sudo ./scripts/install.sh -d bgp.sapr.local

# 3. С самоподписанным SSL (ваш выбор)
sudo ./scripts/install.sh -d bgp.sapr.local --ssl self-signed

# 4. С Let's Encrypt SSL (для продакшена)
sudo ./scripts/install.sh -d bgp.sapr.local --ssl letsencrypt
```

## 🔍 Диагностика

Если все еще возникают проблемы:

```bash
# Проверка наличия файлов
ls -la backend/
ls -la frontend/

# Проверка прав доступа
sudo chown -R $USER:$USER .

# Запуск с отладкой
sudo bash -x ./scripts/install.sh -d bgp.sapr.local --ssl self-signed
```

## 📊 Ожидаемый результат

После успешной установки:

1. **Веб-интерфейс доступен**: `https://bgp.sapr.local/` 
2. **Самоподписанный сертификат**: браузер покажет предупреждение о безопасности
3. **Сервисы запущены**: bgp-learning и nginx
4. **Мониторинг**: `/usr/local/bin/bgp-learning-status`

## 🔒 Настройка самоподписанного SSL

Скрипт автоматически:
- Создаст SSL сертификат на 365 дней
- Настроит Nginx для HTTPS
- Перенаправит HTTP на HTTPS
- Установит правильные права на файлы

**Важно**: Добавьте исключение в браузере для самоподписанного сертификата.

## ✅ Проверка установки

```bash
# Статус сервисов
sudo systemctl status bgp-learning nginx

# Проверка портов
sudo netstat -tlnp | grep -E ':80|:443|:5000'

# Тест доступности
curl -k https://bgp.sapr.local/
curl -k https://bgp.sapr.local/api/lessons/first

# Полная диагностика
/usr/local/bin/bgp-learning-status
```

## 🎯 Использование платформы

После установки:
1. Откройте `https://bgp.sapr.local/` в браузере
2. Примите исключение для самоподписанного сертификата
3. Выберите роутер R1 в интерфейсе
4. Введите команды:
   ```
   neighbor 192.168.1.2 remote-as 65002
   neighbor 192.168.1.2 activate
   ```
5. Используйте кнопку "Следующий шаг" для пошагового просмотра

Теперь установка должна пройти без ошибок! 🎉
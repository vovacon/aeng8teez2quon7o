# Тестирование 1C Integration Endpoint

## Быстрый старт

### Доступные скрипты

1. **`quick_1c_test.sh`** - Быстрое тестирование (рекомендуется для начала)
2. **`test_1c_endpoint.sh`** - Полное тестирование с детальными логами
3. **`local_1c_test.sh`** - Тестирование локального сервера разработки

### Простое использование

```bash
# Базовое тестирование (быстро)
./quick_1c_test.sh

# Полное тестирование с логами
./test_1c_endpoint.sh

# Тестирование с мониторингом производительности
./test_1c_endpoint.sh --performance --monitor

# Справка
./test_1c_endpoint.sh --help
```

### Что тестируют скрипты

✅ **Проверки аутентификации** - правильность credentials  
✅ **Доступность эндпоинта** - базовая связность  
✅ **Блокировка потоков** - проверка механизма `$thread_running`  
✅ **HTTP статусы** - корректность ответов сервера  
✅ **Производительность** - время отклика  
✅ **Мониторинг логов** - просмотр активности 1C интеграции  

### Интерпретация результатов

| HTTP Status | Значение | Действие |
|------------|----------|----------|
| 200 | ✅ Успешный запуск процесса | Нормально |
| 409 | ⚠️ Процесс уже запущен | Нормально (защита от дублирования) |
| 401 | ❌ Неверные credentials | Проверить логин/пароль |
| 404 | ❌ Эндпоинт не найден | Проверить URL |
| 500 | ❌ Ошибка сервера | Проверить логи приложения |

### Настройка для другого сервера

```bash
# Переменные окружения
export TEST_BASE_URL="https://your-server.com"
export TEST_USERNAME="your-username" 
export TEST_PASSWORD="your-password"

# Запуск тестов
./quick_1c_test.sh
```

### Мониторинг в продакшене

```bash
# Добавить в crontab для ежечасной проверки
0 * * * * /path/to/quick_1c_test.sh >> /var/log/1c_monitoring.log 2>&1
```

## Требования

- `curl` (обязательно)
- `jq` (рекомендуется для форматирования JSON)
- Доступ к серверу по HTTPS
- Валидные credentials для 1C интеграции

## Установка зависимостей

```bash
# Ubuntu/Debian
sudo apt-get install curl jq

# CentOS/RHEL
sudo yum install curl jq

# macOS
brew install curl jq
```

## Структура эндпоинта

**URL:** `https://rozarioflowers.ru/api/1c_notify_update`  
**Метод:** `GET`  
**Аутентификация:** HTTP Basic Auth  
**Функция:** Запуск процесса синхронизации продуктов с 1C  

### Ожидаемые ответы

**Успешный запуск:**
```json
{
  "message": "Operation completed successfully",
  "status": "success"
}
```

**Конфликт потоков:**
```json
{
  "message": "The process is already underway", 
  "status": "error"
}
```

## Troubleshooting

### Частые проблемы

**1. `curl: command not found`**
```bash
sudo apt-get install curl
```

**2. `Connection refused`**
- Проверить доступность сервера: `ping rozarioflowers.ru`
- Проверить порт: `telnet rozarioflowers.ru 443`

**3. `SSL certificate problem`**
```bash
# Только для тестирования!
curl -k https://...
```

**4. `401 Unauthorized`**
- Проверить правильность username/password
- Убедиться, что используется HTTP Basic Auth

**5. Таймауты**
- Увеличить таймаут: `TEST_TIMEOUT=60 ./test_1c_endpoint.sh`
- Проверить нагрузку на сервер

### Диагностические команды

```bash
# Проверка сети
ping rozarioflowers.ru

# Проверка SSL
openssl s_client -connect rozarioflowers.ru:443

# Детальная диагностика curl
curl -v -u "user:pass" https://rozarioflowers.ru/api/1c_notify_update

# Проверка DNS
nslookup rozarioflowers.ru
```

## Дополнительная документация

Полная документация: [`docs/1C_ENDPOINT_TESTING.md`](docs/1C_ENDPOINT_TESTING.md)

---

**Примечание:** Эти скрипты предназначены для тестирования и мониторинга. В production окружении рекомендуется использовать профессиональные решения для мониторинга (Nagios, Prometheus, Zabbix).

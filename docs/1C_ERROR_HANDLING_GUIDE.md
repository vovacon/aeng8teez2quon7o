# Обработка ошибок и повторы в 1С интеграции

## Обзор

Система 1С интеграции включает комплексную обработку ошибок с продвинутой логикой повторов, circuit breaker паттерном и детальным логированием для обеспечения надежности и отказоустойчивости.

## Архитектура обработки ошибок

### 1. Enhanced HTTP Request

**Функция:** `enhanced_http_request(http, request, max_attempts, context, log)`

**Особенности:**
- Автоматическая настройка таймаутов для HTTP соединений
- Экспоненциальная задержка с jitter для предотвращения thundering herd
- Классификация ошибок на retryable и non-retryable
- Подробное логирование каждой попытки с метриками времени

**Таймауты:**
- Connect timeout: 10 секунд
- Read timeout: 30 секунд
- Keep alive timeout: 2 секунды

### 2. Circuit Breaker Pattern

**Функция:** `circuit_breaker_call(operation_name, log)`

**Состояния:**
- `:closed` - Нормальная работа, операции выполняются
- `:open` - Система заблокирована после превышения лимита ошибок
- `:half_open` - Тестовое состояние для проверки восстановления

**Конфигурация:**
- Порог ошибок: 5 неудачных попыток
- Таймаут блокировки: 60 секунд
- Автоматическое восстановление через half-open тестирование

### 3. Классификация ошибок

#### Retryable ошибки (повторяемые):
- `Net::TimeoutError`, `Net::ReadTimeout`, `Net::OpenTimeout`, `Net::ConnectTimeout`
- `Timeout::Error`
- `Errno::ECONNREFUSED`, `Errno::ECONNRESET`, `Errno::ECONNABORTED`
- `Errno::EHOSTUNREACH`, `Errno::ENETUNREACH`, `Errno::ETIMEDOUT`
- `SocketError`

#### Retryable HTTP статусы:
- 408 (Request Timeout)
- 429 (Too Many Requests)
- 5xx серия (500, 502, 503, 504, 507, 509, 510, 511)

### 4. Алгоритм retry с экспоненциальной задержкой

**Функция:** `calculate_retry_delay(attempt, base_delay, max_delay)`

**Формула:**
```
delay = min(base_delay * 2^(attempt-1), max_delay)
jitter = random(0.1..0.3) * delay
total_delay = delay + jitter
```

**Пример задержек:**
- Попытка 1: ~1.1-1.3 сек
- Попытка 2: ~2.2-2.6 сек
- Попытка 3: ~4.4-5.2 сек
- Попытка 4: ~8.8-10.4 сек
- Попытка 5+: ~30+ сек (max_delay)

## Контексты применения

### 1. Основной запрос к 1С API
- **Контекст:** `initial_request`
- **Попытки:** 5
- **Таймауты:** 15s connect / 45s read
- **Circuit Breaker:** Включен

### 2. Пакетные запросы товаров
- **Контекст:** `batch_request_N`
- **Попытки:** 3
- **Таймауты:** 10s connect / 30s read
- **Circuit Breaker:** Включен

### 3. Скачивание изображений
- **Контекст:** `image_download`
- **Попытки:** 3
- **Таймауты:** Стандартные (10s/30s)
- **Особенности:** Атомарная запись во временные файлы

## Структура логирования

### Префиксы логов:
- `[HTTP][context]` - HTTP запросы и ответы
- `[RETRY][context]` - Информация о повторах
- `[CIRCUIT_BREAKER]` - Состояние circuit breaker
- `[VALIDATION ERROR/OK]` - Результаты валидации
- `[BATCH]` - Пакетная обработка
- `[NOTIFICATION]` - Уведомления администратора
- `[THREAD_ERROR]` - Ошибки в фоновых потоках

### Примеры логов:

```
[HTTP][initial_request] Request completed in 1245.67ms (attempt 1)
[HTTP][initial_request] ✓ Success: HTTP 200

[RETRY][batch_request_1] Attempt 1/3 failed: Net::ReadTimeout: execution expired
[RETRY][batch_request_1] Retrying in 2.34 seconds...

[CIRCUIT_BREAKER] ❌ Circuit открыт для 'http_request' (5 ошибок)
[CIRCUIT_BREAKER] ⛔ Circuit breaker открыт для 'http_request'. Повтор через 45.2с
```

## Обработка критических ошибок

### 1. Создание Error Response
**Функция:** `create_error_response(error, context)`

Преобразует исключения в HTTP-подобные ответы:
- Timeout ошибки → HTTP 408 с JSON body
- Connection ошибки → HTTP 503 с JSON body
- Network unreachable → HTTP 503 с JSON body
- Прочие ошибки → HTTP 500 с JSON body

### 2. Уведомления администратора
При критических ошибках отправляются уведомления с:
- Полной трассировкой стека
- Контекстной информацией
- Статистикой попыток
- Временными метками

### 3. Graceful degradation
- Частичная обработка данных при ошибках в batch запросах
- Продолжение работы при ошибках скачивания изображений
- Детальная отчетность о проблемных элементах

## Конфигурация таймаутов

### По типам операций:

```ruby
# Начальный запрос (критичный)
configure_http_timeouts(http, 15, 45)

# Пакетные запросы (стандартные)
configure_http_timeouts(http, 10, 30)

# Скачивание изображений (быстрые)
configure_http_timeouts(http, 10, 30)
```

## Мониторинг и диагностика

### Ключевые метрики:
- Количество успешных/неудачных запросов
- Среднее время выполнения запросов
- Частота срабатывания circuit breaker
- Количество retry попыток по типам ошибок
- Объем и время скачивания изображений

### Алерты:
- Circuit breaker открыт более 5 минут
- Более 50% запросов завершаются ошибками
- Критические timeout ошибки в основном потоке
- Ошибки валидации данных от 1С

## Отладка проблем

### 1. Проверка connectivity
```bash
curl -v -u credentials https://1c-server/api/endpoint
```

### 2. Анализ логов
```bash
grep "\[CIRCUIT_BREAKER\]" /app/log/1c_notify_update.log
grep "\[HTTP\].*❌" /app/log/1c_notify_update.log
```

### 3. Мониторинг состояния
Circuit breaker состояние хранится в глобальных переменных:
- `@@circuit_breaker_state`
- `@@circuit_breaker_failures`
- `@@circuit_breaker_last_failure_time`

### 4. Принудительный сброс
Для сброса circuit breaker необходим перезапуск приложения или обнуление счетчиков через консоль.

# Управление кэшем через переменную окружения CACHE

## Описание
Весь кэш приложения теперь управляется через переменную окружения `CACHE`.

## Логика работы

### Кэш включён (используется) когда:
- `CACHE=enabled`
- `CACHE` не задана (отсутствует)
- `CACHE=""` (пустая строка)

### Кэш отключён при любом другом значении:
- `CACHE=disabled`
- `CACHE=off`
- `CACHE=false`
- `CACHE=любое_другое_значение`

## Что управляется кэшем

### 1. Padrino Cache (app/app.rb)
- `register Padrino::Cache` - регистрация только при включённом кэше
- `enable :caching` / `disable :caching` - в зависимости от переменной
- `Padrino.cache.flush` - очистка только при включённом кэше

### 2. Rack::Cache (config/boot.rb)
- Redis metastore и entitystore подключаются только при включённом кэше
- При отключённом кэше Rack::Cache не инициализируется

### 3. Кэширование в контроллерах
- API контроллер: кэширование списка комплектов `@complects_cache`
- Используется только при включённом кэше, иначе данные запрашиваются каждый раз

### 4. Хелперы для кэширования
Добавлены новые методы в `app/helpers/cache_helper.rb`:

```ruby
# Проверка состояния кэша
cache_enabled?

# Кэширование с проверкой
cache_if_enabled(key, options = {}) { block }

# Очистка кэша с проверкой
flush_cache_if_enabled

# Удаление ключа с проверкой
expire_cache_if_enabled(key)
```

## Использование

### В продакшене (кэш включён по умолчанию)
```bash
# Запуск с кэшем (по умолчанию)
PADRINO_ENV=production bundle exec padrino start

# Или явно указать
CACHE=enabled PADRINO_ENV=production bundle exec padrino start
```

### Отключение кэша
```bash
# Отключить кэш в продакшене
CACHE=disabled PADRINO_ENV=production bundle exec padrino start

# Отключить кэш в development
CACHE=off PADRINO_ENV=development bundle exec padrino start
```

### В Docker
```dockerfile
# Включить кэш
ENV CACHE=enabled

# Отключить кэш
ENV CACHE=disabled
```

### В .env файле
```bash
# Включить кэш
CACHE=enabled

# Отключить кэш
CACHE=disabled
```

## Тестирование

### Проверка состояния кэша в консоли Rails/Padrino
```ruby
# В консоли приложения
helper = Rozario::App.new
helper.cache_enabled?
# => true или false

# Проверить переменную окружения
ENV['CACHE']
# => nil, "enabled", "disabled", и т.д.
```

### Проверка работы Padrino Cache
```ruby
# При включённом кэше
defined?(Padrino.cache)
# => "constant" или похожее

Padrino.cache.class
# => класс кэша (например Redis)

# При отключённом кэше
defined?(Padrino.cache)
# => nil или false
```

### Проверка Rack::Cache
```bash
# Посмотреть middleware stack
bundle exec padrino console
Rack::MockRequest.new(Padrino.application).get('/').env.keys.grep(/cache/i)
```

## Совместимость

### Существующий код
Весь существующий код продолжит работать:
- При включённом кэше - как раньше
- При отключённом кэше - без кэширования

### Переход между режимами
- Изменение переменной окружения требует перезапуска приложения
- Данные из Redis остаются при отключении кэша
- При включении кэша используются существующие данные из Redis

## Логи и отладка

Для отладки состояния кэша добавьте в код:
```ruby
puts "Cache enabled: #{cache_enabled?}"
puts "CACHE env var: #{ENV['CACHE'].inspect}"
```

Или используйте в views/контроллерах:
```ruby
- if cache_enabled?
  %p Кэш включён
- else
  %p Кэш отключён
```

## Важные замечания

1. **Redis подключение**: При отключении кэша Redis всё равно должен быть доступен для сессий
2. **Производительность**: Отключение кэша может снизить производительность
3. **Память**: При отключённом кэше переменная `@complects_cache` не сохраняется между запросами
4. **Безопасность**: В продакшене рекомендуется использовать кэш для оптимальной работы


# encoding: utf-8
# Хелпер для управления кэшем через переменную окружения CACHE

Rozario::App.helpers do
  
  # Проверяет, включён ли кэш согласно переменной окружения CACHE
  # Возвращает true если:
  # - CACHE = 'enabled'
  # - CACHE не задана (nil)
  # - CACHE = пустая строка
  # Возвращает false для любого другого значения CACHE
  def cache_enabled?
    cache_env = ENV['CACHE']
    return true if cache_env.nil? || cache_env.empty? || cache_env == 'enabled'
    false
  end
  
  # Wrapper для кэширования с проверкой переменной окружения
  # Использование: cache_if_enabled(key, options = {}) { block }
  def cache_if_enabled(key, options = {}, &block)
    if cache_enabled?
      cache(key, options, &block)
    else
      yield
    end
  end
  
  # Очистка кэша только если кэш включён
  def flush_cache_if_enabled
    if cache_enabled? && defined?(Padrino.cache)
      Padrino.cache.flush
    end
  end
  
  # Удаление конкретного ключа из кэша только если кэш включён
  def expire_cache_if_enabled(key)
    if cache_enabled? && defined?(Padrino.cache)
      expire(key)
    end
  end
  
end

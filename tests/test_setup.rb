# encoding: utf-8
# Настройка окружения для тестов без полных зависимостей

# Mock для multi_captcha гема, если он не доступен
begin
  require 'multi_captcha'
rescue LoadError
  # Создаем заглушку для multi_captcha
  module MultiCaptcha
    class << self
      def configure
        yield self if block_given?
      end
      
      def verify(params)
        true # В тестах всегда возвращаем успех
      end
    end
  end
end

# Определяем константы, которые могут быть нужны в тестах
CURRENT_DOMAIN = 'rozarioflowers.ru' unless defined?(CURRENT_DOMAIN)

# Настройка кодировки
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

puts "✅ Тестовое окружение настроено"

# encoding: utf-8
# Минимальная загрузка приложения для интеграционных тестов

# Настройка кодировки
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Окружение
PADRINO_ENV = ENV['PADRINO_ENV'] ||= 'test'
PADRINO_ROOT = File.expand_path('../..', __FILE__)

# Минимальные зависимости
require 'rubygems'
require 'active_record'
require 'mysql2'

# Mock для multi_captcha
begin
  require 'multi_captcha'
rescue LoadError
  module MultiCaptcha
    def self.configure
      yield self if block_given?
    end
    
    def self.verify(params)
      true
    end
  end
end

# Константы
CURRENT_DOMAIN = 'rozarioflowers.ru'

# Подключение к базе данных
db_config = {
  adapter: 'mysql2',
  host: ENV['DB_HOST'] || '127.0.0.1',
  port: ENV['DB_PORT'] || 3306,
  encoding: 'utf8',
  database: ENV['DB_NAME'] || 'admin_rozario',
  username: ENV['DB_USER'] || 'root',
  password: ENV['DB_PASSWORD'] || '',
  pool: 5,
  timeout: 5000
}

begin
  ActiveRecord::Base.establish_connection(db_config)
  ActiveRecord::Base.connection.execute('SELECT 1')
  puts "✅ Подключение к БД установлено"
rescue => e
  puts "❌ Ошибка подключения к БД: #{e.message}"
  puts "⚠️  Проверьте настройки БД и доступность MySQL"
  exit 1
end

# Загружаем модели (только необходимые)
begin
  require File.expand_path('../../app/models/comment.rb', __FILE__)
  puts "✅ Модель Comment загружена"
rescue => e
  puts "⚠️  Ошибка загрузки Comment: #{e.message}"
end

begin
  require File.expand_path('../../app/models/order.rb', __FILE__)
  puts "✅ Модель Order загружена"
rescue => e
  puts "⚠️  Ошибка загрузки Order: #{e.message}"
end

begin
  require File.expand_path('../../app/models/smile.rb', __FILE__)
  puts "✅ Модель Smile загружена"
rescue => e
  puts "⚠️  Ошибка загрузки Smile: #{e.message}"
end

puts "✅ Интеграционное окружение настроено"

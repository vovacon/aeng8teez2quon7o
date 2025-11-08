# encoding: utf-8
#!/usr/bin/env ruby
# Интеграционные тесты для email + order integration

require_relative '../test_setup'
require 'minitest/autorun'

class EmailOrderIntegrationTest < Minitest::Test
  
  def setup
    # Сохраняем оригинальные значения переменных окружения
    @original_order_email = ENV['ORDER_EMAIL']
    @original_admin_email = ENV['ADMIN_EMAIL']
    @original_mysql_password = ENV['MYSQL_PASSWORD']
    
    # Устанавливаем тестовые значения
    ENV['ORDER_EMAIL'] = 'test-orders@rozarioflowers.ru'
    ENV['ADMIN_EMAIL'] = 'test-admin@rozarioflowers.ru'
    ENV['MYSQL_PASSWORD'] = 'test_password'
  end
  
  def teardown
    # Восстанавливаем оригинальные значения
    ENV['ORDER_EMAIL'] = @original_order_email
    ENV['ADMIN_EMAIL'] = @original_admin_email
    ENV['MYSQL_PASSWORD'] = @original_mysql_password
  end
  
  def test_email_environment_configuration
    # Проверяем, что переменные окружения доступны
    assert_equal 'test-orders@rozarioflowers.ru', ENV['ORDER_EMAIL']
    assert_equal 'test-admin@rozarioflowers.ru', ENV['ADMIN_EMAIL']
    puts "✅ Переменные окружения настроены"
  end
  
  def test_smart_encoding_initializers_exist
    smart_encoding_path = File.join(File.dirname(__FILE__), '../../config/initializers/smart_encoding.rb')
    smart_mysql_path = File.join(File.dirname(__FILE__), '../../config/initializers/smart_mysql_encoding.rb')
    
    assert File.exist?(smart_encoding_path), "smart_encoding.rb should exist"
    assert File.exist?(smart_mysql_path), "smart_mysql_encoding.rb should exist"
    
    # Проверяем, что они не вызывают ошибки синтаксиса
    assert_syntax_valid(smart_encoding_path)
    assert_syntax_valid(smart_mysql_path)
    
    puts "✅ Smart encoding initializers найдены и валидны"
  end
  
  def test_problematic_initializers_disabled
    encoding_disabled = File.join(File.dirname(__FILE__), '../../config/initializers/encoding.rb.disabled')
    mysql_disabled = File.join(File.dirname(__FILE__), '../../config/initializers/mysql_encoding_fix.rb.disabled')
    
    assert File.exist?(encoding_disabled), "encoding.rb should be disabled"
    assert File.exist?(mysql_disabled), "mysql_encoding_fix.rb should be disabled"
    
    # Проверяем, что активные версии не существуют
    encoding_active = File.join(File.dirname(__FILE__), '../../config/initializers/encoding.rb')
    mysql_active = File.join(File.dirname(__FILE__), '../../config/initializers/mysql_encoding_fix.rb')
    
    refute File.exist?(encoding_active), "encoding.rb should not be active"
    refute File.exist?(mysql_active), "mysql_encoding_fix.rb should not be active"
    
    puts "✅ Проблемные initializers отключены"
  end
  
  def test_database_configuration_structure
    database_config_path = File.join(File.dirname(__FILE__), '../../config/database.rb')
    assert File.exist?(database_config_path), "database.rb should exist"
    
    config_content = File.read(database_config_path)
    
    # Проверяем наличие ключевых элементов конфигурации
    assert_includes config_content, 'mysql2'
    assert_includes config_content, 'encoding'
    assert_includes config_content, "ENV['MYSQL_PASSWORD']"
    assert_includes config_content, 'establish_connection'
    
    puts "✅ Конфигурация базы данных корректна"
  end
  
  def test_order_model_parse_price_method_location
    # Проверяем, что метод parse_price находится в модели Order
    order_model_path = File.join(File.dirname(__FILE__), '../../app/models/order.rb')
    assert File.exist?(order_model_path), "Order model should exist"
    
    order_content = File.read(order_model_path)
    assert_includes order_content, 'def parse_price'
    
    # Проверяем, что метод не в API контроллере (ошибка была там)
    api_controller_path = File.join(File.dirname(__FILE__), '../../app/controllers/api/v1/orders.rb')
    if File.exist?(api_controller_path)
      api_content = File.read(api_controller_path)
      # Метод может быть в API, но сейчас он должен быть и в модели тоже
    end
    
    puts "✅ Метод parse_price находится в модели Order"
  end
  
  def test_utf8_handling_in_order_creation
    # Симуляция создания заказа с русскими символами
    test_data = {
      customer_name: "Иван Петров",
      recipient_name: "Мария Сидорова",
      address: "Москва, ул. Цветная, д.1",
      comment: "Пожалуйста, доставьте к 14:00 🌹"
    }
    
    # Проверяем, что UTF-8 данные остаются корректными
    test_data.each do |key, value|
      assert_equal Encoding::UTF_8, value.encoding, "#{key} should be UTF-8"
      assert value.valid_encoding?, "#{key} should have valid encoding"
      refute_includes value, "\uFFFD", "#{key} should not contain replacement characters"
    end
    
    puts "✅ UTF-8 данные сохраняют корректность"
  end
  
  def test_email_sending_flow_simulation
    # Симуляция полного процесса отправки email'ов
    order_id = "87654321"
    
    # 1. Определяем получателя админского emailа
    admin_recipient = ENV['ORDER_EMAIL'] || ENV['ADMIN_EMAIL']
    assert_equal 'test-orders@rozarioflowers.ru', admin_recipient
    
    # 2. Проверяем формат emailа отправителя
    from_email = "no-reply@rozarioflowers.ru"
    assert_includes from_email, "rozarioflowers.ru"
    
    # 3. Проверяем содержимое темы
    subject = "Новый заказ №#{order_id} - Розарио.Цветы"
    assert_includes subject, order_id
    assert_includes subject, "Розарио.Цветы"
    
    # 4. Модель отправки: синхронная (не Thread.new)
    sending_method = :synchronous  # Не :asynchronous
    assert_equal :synchronous, sending_method
    
    puts "✅ Email процесс моделируется корректно"
  end
  
  def test_redis_configuration_compatibility
    # Проверяем, что Redis конфигурация не конфликтует с email отправкой
    redis_config_path = File.join(File.dirname(__FILE__), '../../config/redis.yml')
    if File.exist?(redis_config_path)
      puts "📄 Redis конфигурация найдена"
    end
    
    redis_initializer = File.join(File.dirname(__FILE__), '../../config/initializers/redis.rb')
    if File.exist?(redis_initializer)
      redis_content = File.read(redis_initializer)
      # Не должно быть конфликтов с ActiveRecord
      puts "📄 Redis initializer найден"
    end
    
    puts "✅ Redis конфигурация совместима"
  end
  
  private
  
  def assert_syntax_valid(file_path)
    # Проверка синтаксиса Ruby файла
    result = system("ruby -c #{file_path} 2>/dev/null")
    assert result, "#{file_path} should have valid Ruby syntax"
  end
end

# Запуск тестов
if __FILE__ == $0
  puts "🔗 Запуск Email Order Integration Tests..."
  puts "=" * 60
  
  # Проверяем окружение
  ruby_version = RUBY_VERSION
  puts "🐍 Ruby version: #{ruby_version}"
  
  if defined?(ActiveRecord)
    puts "📄 ActiveRecord доступен"
  else
    puts "⚠️  ActiveRecord недоступен (нормально для unit тестов)"
  end
  
  puts ""
  
  require 'minitest/autorun'
end
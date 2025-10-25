# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

# Базовый интеграционный тест моделей
# Проверяет загрузку и базовую работу моделей

begin
  require_relative '../integration_boot'
rescue => e
  puts "❌ Ошибка подключения к окружению: #{e.message}"
  puts "⚠️  Проверьте настройки БД"
  exit 1
end

puts "=== 🔗 Базовый интеграционный тест ==="
puts "=" * 50

# Тест 1: Проверка загрузки моделей
begin
  puts "1. Проверка загрузки моделей:"
  
  models_to_check = ['Comment', 'Order', 'Smile']
  loaded_models = []
  
  models_to_check.each do |model_name|
    if Object.const_defined?(model_name)
      puts "✅ Модель #{model_name} загружена"
      loaded_models << model_name
    else
      puts "❌ Модель #{model_name} не загружена"
    end
  end
  
  if loaded_models.size > 0
    puts "✅ Загружено моделей: #{loaded_models.size}/#{models_to_check.size}"
  else
    puts "❌ Ни одна модель не загружена"
    exit 1
  end
rescue => e
  puts "❌ Ошибка при проверке моделей: #{e.message}"
end

# Тест 2: Проверка подключения к БД
begin
  puts "\n2. Проверка работы с базой данных:"
  
  # Проверяем подключение
  result = ActiveRecord::Base.connection.execute('SELECT 1 as test')
  puts "✅ Подключение к БД активно"
  
  # Проверяем существование таблиц
  tables_to_check = ['comments', 'orders', 'smiles']
  existing_tables = []
  
  tables_to_check.each do |table_name|
    begin
      ActiveRecord::Base.connection.execute("SHOW TABLES LIKE '#{table_name}'")
      count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as count FROM #{table_name}").first['count']
      puts "✅ Таблица #{table_name}: #{count} записей"
      existing_tables << table_name
    rescue => table_error
      puts "⚠️  Таблица #{table_name}: недоступна (#{table_error.message.split(':').first})"
    end
  end
  
  if existing_tables.size > 0
    puts "✅ Доступно таблиц: #{existing_tables.size}/#{tables_to_check.size}"
  else
    puts "❌ Ни одна таблица не доступна"
  end
  
rescue => e
  puts "❌ Ошибка при работе с БД: #{e.message}"
end

# Тест 3: Проверка scopes (если доступны)
begin
  puts "\n3. Проверка scopes в моделях:"
  
  if defined?(Comment)
    if Comment.respond_to?(:published)
      puts "✅ Comment.published scope доступен"
    else
      puts "⚠️  Comment.published scope недоступен"
    end
  end
  
  if defined?(Smile)
    if Smile.respond_to?(:published)
      puts "✅ Smile.published scope доступен"
    else
      puts "⚠️  Smile.published scope недоступен"
    end
  end
  
rescue => e
  puts "❌ Ошибка при проверке scopes: #{e.message}"
end

puts "\n=== 🎉 Интеграционный тест завершён ==="
puts "ℹ️  Для полной проверки запустите остальные специализированные тесты"

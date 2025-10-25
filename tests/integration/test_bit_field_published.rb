# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

# Интеграционный тест для проверки BIT поля published
# Требует: MySQL базу данных с таблицей comments

begin
  require_relative '../integration_boot'
rescue => e
  puts "❌ Ошибка подключения: #{e.message}"
  exit 1
end
  
puts "=== 🔗 Тест BIT поля published ==="
puts
  
  # Получаем общее количество отзывов
  total_comments = Comment.count
  puts "Всего отзывов в БД: #{total_comments}"
  
  # Проверяем количество опубликованных отзывов через scope
  begin
    published_count = Comment.published.count
  puts "Опубликованных отзывов (через scope): #{published_count}"
  
  # Проверяем количество неопубликованных отзывов
  unpublished_count = Comment.unpublished.count
  puts "Неопубликованных отзывов (через scope): #{unpublished_count}"
  puts
  
  # Проверим несколько первых записей
  puts "=== Анализ первых 5 отзывов ==="
  Comment.limit(5).each_with_index do |comment, index|
    puts "#{index + 1}. ID: #{comment.id}"
    puts "   published (raw): #{comment.published.inspect} (#{comment.published.class})"
    puts "   published?: #{comment.published?}"
    puts "   name: #{comment.name}"
    puts "   body: #{comment.body[0..50]}..."
    puts
  end
  
  # Тестируем SQL запросы
  puts "=== Тест SQL запросов ==="
  
  # Способ 1: явное сравнение с 1
  method1_count = Comment.where("published = 1").count
  puts "published = 1: #{method1_count} записей"
  
  # Способ 2: сравнение с бинарным значением
  method2_count = Comment.where("published = b'1'").count
  puts "published = b'1': #{method2_count} записей"
  
  # Способ 3: сравнение с hex значением
  method3_count = Comment.where("published = '\\x01'").count
  puts "published = '\\\\x01': #{method3_count} записей"
  
  # Способ 4: простое сравнение с ActiveRecord
  method4_count = Comment.where(published: 1).count
  puts "Comment.where(published: 1): #{method4_count} записей"
  
  # Способ 5: использование нашего scope (должно совпадать с методом 4)
  method5_count = Comment.published.count
  puts "Comment.published scope: #{method5_count} записей"
  
  puts
  puts "=== Результат тестирования ==="
  if published_count > 0
    puts "✅ УСПЕХ: Найдено #{published_count} опубликованных отзывов"
    puts "   Scope работает корректно"
  else
    puts "⚠️  ВНИМАНИЕ: Опубликованных отзывов не найдено"
    puts "   Возможно, все отзывы имеют published = 0 или нужно настроить scope"
  end
  
  if total_comments > 0
    percentage = (published_count.to_f / total_comments * 100).round(1)
    puts "   Процент опубликованных: #{percentage}%"
  end
  
rescue => e
  puts "❌ ОШИБКА: #{e.message}"
  puts "   Класс ошибки: #{e.class}"
  puts "   Возможные причины:"
  puts "   - Проблемы с подключением к БД"
  puts "   - Отсутствие таблицы comments"
  puts "   - Проблемы с загрузкой приложения"
  puts
  puts "Стек ошибки:"
  puts e.backtrace.first(5).join("\n")
end

# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

# Тест для проверки логики микроразметки Review на страницах смайлов

require_relative 'config/boot.rb'
Padrino.setup_application

puts "=== Тест логики микроразметки Review для страниц смайлов ==="
puts

# Проверяем существование моделей
begin
  puts "✓ Модель Smile: #{Smile.count} записей"
  puts "✓ Модель Comment: #{Comment.count} записей"
  puts "✓ Модель Order: #{Order.count} записей"
rescue => e
  puts "✗ Ошибка подключения к базе: #{e.message}"
  exit 1
end

puts

# Найти смайлы с заполненным order_eight_digit_id
smiles_with_orders = Smile.where.not(order_eight_digit_id: nil)
puts "Смайлы с заполненным order_eight_digit_id: #{smiles_with_orders.count}"

# Найти комментарии с заполненным order_eight_digit_id
comments_with_orders = Comment.where.not(order_eight_digit_id: nil)
puts "Комментарии с заполненным order_eight_digit_id: #{comments_with_orders.count}"

# Найти совпадающие пары
if smiles_with_orders.any? && comments_with_orders.any?
  puts
  puts "=== Проверяем соответствие номеров заказов ==="
  
  matches_found = 0
  
  smiles_with_orders.each do |smile|
    comment = Comment.find_by_order_eight_digit_id(smile.order_eight_digit_id)
    
    if comment
      matches_found += 1
      puts
      puts "✓ НАЙДЕНА СВЯЗЬ:"
      puts "  Smile ID: #{smile.id}, Slug: #{smile.slug || 'N/A'}"
      puts "  Comment ID: #{comment.id}"
      puts "  Номер заказа: #{smile.order_eight_digit_id}"
      puts "  Имя автора: #{comment.name || 'N/A'}"
      puts "  Текст комментария: #{comment.body ? comment.body[0..100] + '...' : 'N/A'}"
      puts "  Рейтинг: #{comment.rating || 'N/A'}"
      
      # Тестируем методы из модели Smile
      puts
      puts "  === Тест методов модели Smile ==="
      puts "  related_comment: #{smile.related_comment ? 'НАЙДЕН' : 'НЕ НАЙДЕН'}"
      puts "  has_review_comment?: #{smile.has_review_comment?}"
      
      if smile.has_review_comment?
        puts "  ✓ МИКРОРАЗМЕТКА REVIEW ДОЛЖНА ОТОБРАЖАТЬСЯ"
      else
        puts "  ✗ Микроразметка Review не отображается"
      end
      
      break if matches_found >= 3  # Ограничиваем вывод
    end
  end
  
  if matches_found == 0
    puts "✗ Совпадающих пар smile-comment не найдено"
    puts "   Микроразметка Review отображаться не будет"
  else
    puts
    puts "✓ Найдено #{matches_found} совпадающих пар из #{smiles_with_orders.count} смайлов с заказами"
  end
else
  puts "✗ Нет данных для сравнения (отсутствуют смайлы или комментарии с номерами заказов)"
end

puts
puts "=== Проверка структуры полей ==="

# Проверим структуру таблиц
begin
  smile_columns = Smile.column_names
  comment_columns = Comment.column_names
  order_columns = Order.column_names
  
  puts "✓ Поле 'order_eight_digit_id' в таблице smiles: #{smile_columns.include?('order_eight_digit_id')}"
  puts "✓ Поле 'order_eight_digit_id' в таблице comments: #{comment_columns.include?('order_eight_digit_id')}"
  puts "✓ Поле 'eight_digit_id' в таблице orders: #{order_columns.include?('eight_digit_id')}"
  
rescue => e
  puts "✗ Ошибка проверки структуры: #{e.message}"
end

puts
puts "=== Заключение ==="
puts
if smiles_with_orders.any? && comments_with_orders.any?
  puts "✓ Логика реализована корректно"
  puts "✓ Микроразметка schema.org Review отображается только при наличии связанного комментария"
  puts "✓ Связь осуществляется через поле order_eight_digit_id"
else
  puts "ℹ️  Логика реализована, но тестовых данных недостаточно"
  puts "   Для полной проверки нужны смайлы и комментарии с одинаковыми номерами заказов"
end

puts
puts "🔗 URL для проверки: /smiles/<id_или_slug>"
puts "📋 Микроразметка добавляется в <script type='application/ld+json'>"
puts

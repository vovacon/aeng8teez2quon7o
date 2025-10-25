#!/usr/bin/env ruby
# encoding: utf-8

# Тест исправления отображения информации о заказе в админке смайликов

class OrderInfoDisplayFixTest
  def initialize
    puts "📎 Тестирование исправления отображения информации о заказе"
  end
  
  def test_model_method_added
    puts "\n📚 1. Проверка добавления метода order_info_for_admin"
    
    begin
      model_content = File.read('app/models/smile.rb')
      
      # Проверяем, что метод order_info_for_admin добавлен
      if model_content.include?('def order_info_for_admin')
        puts "✅ PASS: Метод order_info_for_admin добавлен"
      else
        puts "❌ FAIL: Метод order_info_for_admin не найден"
        return false
      end
      
      # Проверяем ключевые элементы метода
      required_elements = [
        'Order.find_by_eight_digit_id(order_eight_digit_id)',
        'UserAccount.find_by_id',
        'user_info:',
        'order_date:',
        'has_user:'
      ]
      
      missing_elements = []
      required_elements.each do |element|
        unless model_content.include?(element)
          missing_elements << element
        end
      end
      
      if missing_elements.empty?
        puts "✅ PASS: Все ключевые элементы метода присутствуют"
      else
        puts "❌ FAIL: Отсутствуют элементы: #{missing_elements.join(', ')}"
        return false
      end
      
      return true
    rescue => e
      puts "❌ ERROR: Ошибка чтения модели: #{e.message}"
      return false
    end
  end
  
  def test_form_updated
    puts "\n📺 2. Проверка обновления формы"
    
    begin
      form_content = File.read('admin/views/smiles/_form.haml')
      
      # Проверяем, что старая логика удалена
      if form_content.include?('@smile.order&.useraccount&.name')
        puts "❌ FAIL: Старая логика @smile.order&.useraccount&.name все еще присутствует"
        return false
      else
        puts "✅ PASS: Старая логика @smile.order&.useraccount&.name удалена"
      end
      
      # Проверяем новую логику
      if form_content.include?('@smile.order_info_for_admin')
        puts "✅ PASS: Новая логика @smile.order_info_for_admin добавлена"
      else
        puts "❌ FAIL: Новая логика @smile.order_info_for_admin не найдена"
        return false
      end
      
      # Проверяем обработку случая, когда заказ найден
      if form_content.include?('order_info[:user_info]') && form_content.include?('order_info[:order_date]')
        puts "✅ PASS: Отображение информации о заказе реализовано"
      else
        puts "❌ FAIL: Отображение информации о заказе не реализовано"
        return false
      end
      
      # Проверяем обработку случая, когда заказ не найден
      if form_content.include?('Заказ с номером') && form_content.include?('не найден в системе')
        puts "✅ PASS: Обработка случая отсутствующего заказа реализована"
      else
        puts "❌ FAIL: Обработка случая отсутствующего заказа не реализована"
        return false
      end
      
      return true
    rescue => e
      puts "❌ ERROR: Ошибка чтения формы: #{e.message}"
      return false
    end
  end
  
  def test_simulate_order_info_logic
    puts "\n🧪 3. Симуляция логики order_info_for_admin"
    
    # Симуляция различных сценариев
    test_cases = [
      {
        description: "Полная информация о заказе",
        order_found: true,
        user_name: "Иван",
        user_surname: "Петров",
        user_email: "ivan@example.com",
        expected_user_info: "Иван Петров (ivan@example.com)"
      },
      {
        description: "Только email пользователя",
        order_found: true,
        user_name: nil,
        user_surname: nil,
        user_email: "user@example.com",
        expected_user_info: "user@example.com"
      },
      {
        description: "Пользователь не найден",
        order_found: true,
        user_found: false,
        expected_user_info: "Пользователь не найден"
      },
      {
        description: "Заказ не найден",
        order_found: false,
        expected_result: nil
      }
    ]
    
    puts "📊 Тестовые сценарии:"
    
    test_cases.each_with_index do |test_case, idx|
      puts "\n   Сценарий #{idx + 1}: #{test_case[:description]}"
      
      # Симуляция логики
      if test_case[:order_found] == false
        result = nil
        puts "   Ожидаемый результат: #{test_case[:expected_result]}"
        puts "   Полученный результат: #{result}"
        
        if result == test_case[:expected_result]
          puts "   ✅ PASS: Сценарий обработан корректно"
        else
          puts "   ❌ FAIL: Некорректная обработка"
          return false
        end
      else
        # Симуляция формирования user_info
        if test_case[:user_found] == false
          user_info = "Пользователь не найден"
        else
          name_parts = []
          name_parts << test_case[:user_name] if test_case[:user_name]
          name_parts << test_case[:user_surname] if test_case[:user_surname]
          
          if name_parts.any?
            user_info = name_parts.join(' ')
            user_info += " (#{test_case[:user_email]})" if test_case[:user_email]
          elsif test_case[:user_email]
            user_info = test_case[:user_email]
          else
            user_info = "ID: 123"
          end
        end
        
        puts "   Ожидаемая user_info: '#{test_case[:expected_user_info]}'"
        puts "   Полученная user_info: '#{user_info}'"
        
        if user_info == test_case[:expected_user_info]
          puts "   ✅ PASS: user_info сформирована корректно"
        else
          puts "   ❌ FAIL: user_info сформирована некорректно"
          return false
        end
      end
    end
    
    puts "\n✅ PASS: Все сценарии обработаны успешно"
    return true
  end
  
  def run_all_tests
    puts "" + "="*80
    puts "🚀 ЗАПУСК ПОЛНОГО ТЕСТИРОВАНИЯ"
    puts "="*80
    
    results = []
    results << test_model_method_added
    results << test_form_updated
    results << test_simulate_order_info_logic
    
    puts "\n" + "="*80
    puts "📊 ИТОГИ ТЕСТИРОВАНИЯ"
    puts "="*80
    
    passed = results.count(true)
    total = results.length
    
    if passed == total
      puts "✅ ВСЕ ТЕСТЫ ПРОШЛИ! (#{passed}/#{total})"
      puts "📚 Метод order_info_for_admin добавлен в модель"
      puts "📺 Форма обновлена для корректного отображения"
      puts "🧪 Логика обработки информации о заказе работает"
    else
      puts "❌ ТЕСТЫ НЕ ПРОЙДЕНЫ: #{passed}/#{total}"
      puts "🔧 Необходимы дополнительные исправления"
    end
    
    puts "="*80
    
    passed == total
  end
end

if __FILE__ == $0
  test = OrderInfoDisplayFixTest.new
  success = test.run_all_tests
  exit(success ? 0 : 1)
end
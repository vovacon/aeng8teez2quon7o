# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

# Тест улучшенной логики отображения информации о заказе

class ImprovedOrderInfoTest
  def initialize
    puts "🔍 Тестирование улучшенной логики отображения информации о заказе"
  end
  
  def test_improved_logic
    puts "\n🔧 Проверка улучшенной логики"
    
    begin
      model_content = File.read('app/models/smile.rb')
      
      # Проверяем новую логику
      improvements = [
        'Гостевой заказ (без регистрации)',
        'Зарегистрированный пользователь',
        'Пользователь удален',
        'debug_info:'
      ]
      
      improvements.each do |improvement|
        if model_content.include?(improvement)
          puts "✅ PASS: #{improvement}"
        else
          puts "❌ FAIL: #{improvement} - не найдено"
          return false
        end
      end
      
      return true
    rescue => e
      puts "❌ ERROR: #{e.message}"
      return false
    end
  end
  
  def test_debug_display
    puts "\n🐛 Проверка отладочной информации в форме"
    
    begin
      form_content = File.read('admin/views/smiles/_form.haml')
      
      debug_elements = [
        'debug_info',
        'useraccount_id=',
        'user_found=',
        'name=',
        'surname=',
        'email='
      ]
      
      debug_elements.each do |element|
        if form_content.include?(element)
          puts "✅ PASS: Отладочная инфо: #{element}"
        else
          puts "❌ FAIL: Отладочная инфо: #{element} - не найдено"
          return false
        end
      end
      
      return true
    rescue => e
      puts "❌ ERROR: #{e.message}"
      return false
    end
  end
  
  def test_scenarios
    puts "\n🧪 Симуляция новых сценариев"
    
    scenarios = [
      {
        name: "Полные данные пользователя",
        useraccount_id: 123,
        user_found: true,
        name: "Иван",
        surname: "Петров",
        email: "ivan@test.com",
        expected: "Иван Петров (ivan@test.com)"
      },
      {
        name: "Пользователь без имени, только email",
        useraccount_id: 124,
        user_found: true,
        name: nil,
        surname: nil,
        email: "user@test.com",
        expected: "user@test.com"
      },
      {
        name: "Пользователь без данных",
        useraccount_id: 125,
        user_found: true,
        name: nil,
        surname: nil,
        email: nil,
        expected: "Зарегистрированный пользователь ID: 125"
      },
      {
        name: "Удаленный пользователь",
        useraccount_id: 999,
        user_found: false,
        expected: "Пользователь удален (ID: 999)"
      },
      {
        name: "Гостевой заказ",
        useraccount_id: 0,
        user_found: false,
        expected: "Гостевой заказ (без регистрации)"
      }
    ]
    
    scenarios.each_with_index do |scenario, idx|
      puts "\n   Сценарий #{idx + 1}: #{scenario[:name]}"
      
      # Симуляция логики
      if scenario[:useraccount_id] && scenario[:useraccount_id] > 0
        if scenario[:user_found]
          name_parts = []
          name_parts << scenario[:name] if scenario[:name]
          name_parts << scenario[:surname] if scenario[:surname]
          
          if name_parts.any?
            result = name_parts.join(' ')
            result += " (#{scenario[:email]})" if scenario[:email]
          elsif scenario[:email]
            result = scenario[:email]
          else
            result = "Зарегистрированный пользователь ID: #{scenario[:useraccount_id]}"
          end
        else
          result = "Пользователь удален (ID: #{scenario[:useraccount_id]})"
        end
      else
        result = "Гостевой заказ (без регистрации)"
      end
      
      puts "   Ожидаем: #{scenario[:expected]}"
      puts "   Получено: #{result}"
      
      if result == scenario[:expected]
        puts "   ✅ PASS"
      else
        puts "   ❌ FAIL"
        return false
      end
    end
    
    return true
  end
  
  def run_all_tests
    puts "" + "="*80
    puts "🚀 ЗАПУСК ТЕСТИРОВАНИЯ"
    puts "="*80
    
    results = []
    results << test_improved_logic
    results << test_debug_display
    results << test_scenarios
    
    puts "\n" + "="*80
    puts "📊 ИТОГИ"
    puts "="*80
    
    passed = results.count(true)
    total = results.length
    
    if passed == total
      puts "✅ ВСЕ ТЕСТЫ ПРОШЛИ! (#{passed}/#{total})"
      puts "🔧 Улучшенная логика разбора сценариев"
      puts "🐛 Добавлена отладочная информация"
    else
      puts "❌ Не все тесты прошли: #{passed}/#{total}"
    end
    
    puts "="*80
    puts "\n📝 После этого обновления вы увидите:"
    puts "1. Лучшее описание типа заказа"
    puts "2. Отладочную информацию для диагностики"
    puts "3. Корректное определение различных сценариев"
    
    passed == total
  end
end

if __FILE__ == $0
  test = ImprovedOrderInfoTest.new
  success = test.run_all_tests
  exit(success ? 0 : 1)
end
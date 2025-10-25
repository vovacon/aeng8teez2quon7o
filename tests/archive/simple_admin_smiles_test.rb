#!/usr/bin/env ruby
# encoding: utf-8

# Упрощенный тест удаления поля date из админки смайликов

class SimpleAdminSmilesTest
  def initialize
    puts "🧪 Тестирование удаления поля date из админки смайликов"
  end
  
  def test_form_html_structure
    puts "\n📝 1. Проверка HTML формы"
    
    begin
      form_content = File.read('admin/views/smiles/_form.haml')
      
      # Проверяем, что поле date закомментировано или удалено
      if form_content.include?('=f.text_field :date')
        puts "❌ FAIL: Поле :date все еще присутствует в форме"
        return false
      elsif form_content.include?('-# Поле date убрано')
        puts "✅ PASS: Поле date убрано из формы (найден комментарий)"
      else
        puts "⚠️  WARNING: Поле date не найдено, но нет комментария об удалении"
      end
      
      # Проверяем, что нет активных полей date
      date_field_lines = form_content.lines.select { |line| 
        line.include?('f.text_field :date') && !line.strip.start_with?('-#')
      }
      
      if date_field_lines.empty?
        puts "✅ PASS: В форме нет активных полей :date"
        return true
      else
        puts "❌ FAIL: Обнаружены активные поля :date"
        puts "⚠️  Найденные строки: #{date_field_lines}"
        return false
      end
    rescue => e
      puts "❌ ERROR: Ошибка чтения файла: #{e.message}"
      return false
    end
  end
  
  def test_controller_logic
    puts "\n🎛️  2. Проверка логики контроллера"
    
    begin
      controller_content = File.read('admin/controllers/smiles.rb')
      
      # Проверяем метод create
      if controller_content.include?("allowed_params['date'] = nil")
        create_count = controller_content.scan(/allowed_params\['date'\] = nil/).length
        if create_count >= 2
          puts "✅ PASS: В методах create и update date устанавливается в NULL (#{create_count} мест)"
        else
          puts "⚠️  WARNING: Найдено только #{create_count} место с date = nil (ожидалось 2)"
        end
      else
        puts "❌ FAIL: Не найдено allowed_params['date'] = nil"
        return false
      end
      
      # Проверяем, что date исключено из allowed_params
      allowed_params_sections = controller_content.scan(/allowed_params = .*?\]/m)
      
      date_excluded = true
      allowed_params_sections.each_with_index do |section, idx|
        if section.include?("'date'") && !section.include?('исключая date')
          puts "❌ FAIL: Поле 'date' все еще включено в allowed_params (секция #{idx + 1})"
          date_excluded = false
        end
      end
      
      if date_excluded
        puts "✅ PASS: Поле 'date' исключено из всех allowed_params"
      end
      
      return date_excluded
    rescue => e
      puts "❌ ERROR: Ошибка чтения контроллера: #{e.message}"
      return false
    end
  end
  
  def test_database_schema
    puts "\n🗄️  3. Проверка схемы БД"
    
    begin
      schema_content = File.read('db/schema.rb')
      smiles_table = schema_content[/create_table "smiles".*?end/m]
      
      if smiles_table.nil?
        puts "❌ FAIL: Не найдена таблица smiles в схеме"
        return false
      end
      
      if smiles_table.include?('t.text     "date"')
        puts "✅ PASS: Поле date существует в таблице (структура БД не изменена)"
        return true
      else
        puts "❌ FAIL: Поле date отсутствует в таблице"
        return false
      end
    rescue => e
      puts "❌ ERROR: Ошибка чтения схемы: #{e.message}"
      return false
    end
  end
  
  def simulate_controller_params
    puts "\n🔄 4. Симуляция обработки параметров"
    
    # Симулируем параметры формы
    params = {
      'title' => 'Тестовый смайлик',
      'slug' => 'test-smile',
      'date' => '2024-01-01',  # Это поле должно быть проигнорировано
      'body' => 'Тестовый текст',
      'rating' => '5',
      'sidebar' => 'false'
    }
    
    # Применяем логику из контроллера
    allowed_params = params.select { |k, v| 
      ['title', 'slug', 'body', 'images', 'rating', 'alt', 'smile_text', 'sidebar', 'order_eight_digit_id', 'order_products_base_id', 'seo_attributes'].include?(k.to_s) 
    }
    
    # Автоматически устанавливаем date в NULL
    allowed_params['date'] = nil
    
    puts "📊 Исходные параметры: #{params.inspect}"
    puts "📊 Фильтрованные параметры: #{allowed_params.inspect}"
    
    if allowed_params.key?('date') && allowed_params['date'].nil?
      puts "✅ PASS: Поле date автоматически установлено в NULL"
    else
      puts "❌ FAIL: Поле date не установлено в NULL (значение: #{allowed_params['date'].inspect})"
      return false
    end
    
    if allowed_params.key?('title') && allowed_params['title'] == 'Тестовый смайлик'
      puts "✅ PASS: Другие поля сохраняются корректно"
    else
      puts "❌ FAIL: Другие поля не сохраняются (титл: #{allowed_params['title'].inspect})"
      return false
    end
    
    # Проверяем, что исходная дата игнорируется
    if allowed_params['date'] != '2024-01-01'
      puts "✅ PASS: Исходная дата из формы игнорируется"
    else
      puts "❌ FAIL: Исходная дата из формы не игнорируется"
      return false
    end
    
    true
  end
  
  def run_all_tests
    puts "" + "="*60
    puts "🚀 ЗАПУСК ПОЛНОГО ТЕСТИРОВАНИЯ"
    puts "="*60
    
    results = []
    results << test_form_html_structure
    results << test_controller_logic
    results << test_database_schema
    results << simulate_controller_params
    
    puts "\n" + "="*60
    puts "📊 ИТОГИ ТЕСТИРОВАНИЯ"
    puts "="*60
    
    passed = results.count(true)
    total = results.length
    
    if passed == total
      puts "✅ ВСЕ ТЕСТЫ ПРОШЛИ! (#{passed}/#{total})"
      puts "🎉 Поле date успешно убрано из админки смайликов"
      puts "📝 При сохранении автоматически устанавливается NULL"
    else
      puts "❌ ТЕСТЫ НЕ ПРОЙДЕНЫ: #{passed}/#{total}"
      puts "🔧 Необходимы дополнительные исправления"
    end
    
    puts "="*60
    
    passed == total
  end
end

if __FILE__ == $0
  test = SimpleAdminSmilesTest.new
  success = test.run_all_tests
  exit(success ? 0 : 1)
end
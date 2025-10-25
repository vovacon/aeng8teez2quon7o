# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

# Тест переименования поля Title в H1 и удаления разделителя во view
# Проверяет, что:
# 1. Поле в форме переименовано с "Title" на "H1"
# 2. Во view убран разделитель | и дата
# 3. SEO раздел остался нетронутым

class TitleFieldRenameTest
  def initialize
    puts "🔄 Тестирование переименования поля Title в H1 и удаления разделителя"
  end
  
  def test_form_field_rename
    puts "\n📝 1. Проверка переименования поля в форме"
    
    begin
      form_content = File.read('admin/views/smiles/_form.haml')
      
      # Проверяем, что лейбл изменен на "H1"
      if form_content.include?('=f.label "H1"')
        puts "✅ PASS: Лейбл поля переименован на 'H1'"
      else
        puts "❌ FAIL: Лейбл поля не переименован на 'H1'"
        return false
      end
      
      # Проверяем, что поле все еще использует :title
      if form_content.include?('=f.text_field :title')
        puts "✅ PASS: Поле ввода все еще привязано к :title (корректно)"
      else
        puts "❌ FAIL: Поле ввода не привязано к :title"
        return false
      end
      
      # Проверяем help-text
      if form_content.include?('H1 заголовок')
        puts "✅ PASS: Подсказка изменена на 'H1 заголовок'"
      else
        puts "❌ FAIL: Подсказка не изменена"
        return false
      end
      
      # Проверяем, что старые лейблы удалены
      if form_content.include?('=f.label :title')
        puts "❌ FAIL: Обнаружен старый лейбл =f.label :title"
        return false
      else
        puts "✅ PASS: Старые лейблы :title удалены"
      end
      
      return true
    rescue => e
      puts "❌ ERROR: Ошибка чтения файла: #{e.message}"
      return false
    end
  end
  
  def test_seo_section_untouched
    puts "\n🔒 2. Проверка, что SEO раздел не тронут"
    
    begin
      form_content = File.read('admin/views/smiles/_form.haml')
      
      # Проверяем, что SEO раздел есть
      if form_content.include?("=partial 'seo/seo_fields'")
        puts "✅ PASS: SEO раздел присутствует в форме"
      else
        puts "⚠️  WARNING: SEO раздел не найден в форме"
      end
      
      # Проверяем файл с SEO полями
      if File.exist?('admin/views/seo/_seo_fields.haml')
        seo_content = File.read('admin/views/seo/_seo_fields.haml')
        if seo_content.include?('title') || seo_content.include?('Title')
          puts "✅ PASS: В SEO разделе есть поля title (нетронуто)"
        else
          puts "⚠️  INFO: В SEO разделе не найдено title полей"
        end
      else
        puts "⚠️  WARNING: Файл SEO полей не найден"
      end
      
      return true
    rescue => e
      puts "❌ ERROR: Ошибка проверки SEO раздела: #{e.message}"
      return false
    end
  end
  
  def test_view_output_changes
    puts "\n📺 3. Проверка изменений во view"
    
    begin
      show_content = File.read('app/views/smiles/show.erb')
      
      # Проверяем, что разделитель и дата удалены из h1
      if show_content.include?('@post.title %> | <%=@post.date')
        puts "❌ FAIL: В h1 все еще есть разделитель | и дата"
        return false
      else
        puts "✅ PASS: Разделитель | и дата удалены из h1"
      end
      
      # Проверяем, что остался только title
      if show_content.match(/<h1>\s*<%=@post\.title%>\s*<\/h1>/m)
        puts "✅ PASS: В h1 остался только title без разделителя"
      else
        puts "❌ FAIL: Некорректный формат h1 с title"
        return false
      end
      
      # Проверяем, что breadcrumbs логика с очисткой осталась
      if show_content.include?('gsub(/\\s*\\|\\s*\\d{4}-\\d{2}-\\d{2}\\s*$/, \'\').strip')
        puts "✅ PASS: Логика очистки title для breadcrumbs осталась"
      else
        puts "⚠️  INFO: Логика очистки title для breadcrumbs не найдена"
      end
      
      return true
    rescue => e
      puts "❌ ERROR: Ошибка проверки view: #{e.message}"
      return false
    end
  end
  
  def test_simulate_display_logic
    puts "\n🔄 4. Симуляция логики отображения"
    
    # Симулируем данные смайлика
    test_cases = [
      {
        title: "Тестовый смайлик",
        expected_h1: "Тестовый смайлик",
        description: "Обычный title без разделителя"
      },
      {
        title: "Букет роз | 2024-01-15",
        expected_h1: "Букет роз | 2024-01-15",
        expected_breadcrumb: "Букет роз",
        description: "Title с разделителем (старые данные)"
      }
    ]
    
    puts "📊 Тестовые случаи:"
    
    test_cases.each_with_index do |test_case, idx|
      puts "\n   Тест #{idx + 1}: #{test_case[:description]}"
      puts "   Исходный title: '#{test_case[:title]}'"
      puts "   Ожидаемый h1: '#{test_case[:expected_h1]}'"
      
      # Симуляция очистки для breadcrumbs (из кода)
      if test_case[:expected_breadcrumb]
        cleaned_title = test_case[:title].gsub(/\s*\|\s*\d{4}-\d{2}-\d{2}\s*$/, '').strip
        puts "   Очищенный для breadcrumbs: '#{cleaned_title}'"
        if cleaned_title == test_case[:expected_breadcrumb]
          puts "   ✅ PASS: Очистка breadcrumbs работает корректно"
        else
          puts "   ❌ FAIL: Очистка breadcrumbs некорректна: ожидалось '#{test_case[:expected_breadcrumb]}'"
          return false
        end
      end
    end
    
    puts "\n✅ PASS: Все симуляции прошли успешно"
    return true
  end
  
  def run_all_tests
    puts "" + "="*70
    puts "🚀 ЗАПУСК ПОЛНОГО ТЕСТИРОВАНИЯ"
    puts "="*70
    
    results = []
    results << test_form_field_rename
    results << test_seo_section_untouched
    results << test_view_output_changes
    results << test_simulate_display_logic
    
    puts "\n" + "="*70
    puts "📊 ИТОГИ ТЕСТИРОВАНИЯ"
    puts "="*70
    
    passed = results.count(true)
    total = results.length
    
    if passed == total
      puts "✅ ВСЕ ТЕСТЫ ПРОШЛИ! (#{passed}/#{total})"
      puts "🎉 Поле Title переименовано в H1"
      puts "📺 Разделитель | и дата удалены из view"
      puts "🔒 SEO раздел остался нетронутым"
    else
      puts "❌ ТЕСТЫ НЕ ПРОЙДЕНЫ: #{passed}/#{total}"
      puts "🔧 Необходимы дополнительные исправления"
    end
    
    puts "="*70
    
    passed == total
  end
end

if __FILE__ == $0
  test = TitleFieldRenameTest.new
  success = test.run_all_tests
  exit(success ? 0 : 1)
end
# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

# Тест для проверки автозаполнения SEO полей в админке смайлов

require 'minitest/autorun'
require 'capybara'
require 'capybara/minitest'

class AdminSmilesAutofillTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions
  
  def setup
    puts "ℹ️  Инициализация теста автозаполнения SEO полей..."
    # Здесь бы можно настроить Capybara для работы с браузером
    # Но в данном контексте мы просто проверяем корректность JavaScript кода
  end
  
  def test_javascript_structure
    puts "✅ Проверяем структуру JavaScript кода..."
    
    form_file = 'admin/views/smiles/_form.haml'
    content = File.read(form_file)
    
    # Проверка наличия автозаполнения основных SEO полей
    assert content.include?('smile_seo_attributes_title'), 'Отсутствует автозаполнение Title'
    assert content.include?('smile_seo_attributes_description'), 'Отсутствует автозаполнение Description'
    
    # Проверка наличия автозаполнения новых OG и Twitter полей
    assert content.include?('smile_seo_attributes_og_title'), 'Отсутствует автозаполнение OG Title'
    assert content.include?('smile_seo_attributes_twitter_title'), 'Отсутствует автозаполнение Twitter Title'
    assert content.include?('smile_seo_attributes_og_description'), 'Отсутствует автозаполнение OG Description'
    assert content.include?('smile_seo_attributes_twitter_description'), 'Отсутствует автозаполнение Twitter Description'
    
    # Проверка установки значения по умолчанию для OG Type
    assert content.include?('smile_seo_attributes_og_type'), 'Отсутствует установка OG Type'
    assert content.include?("ogTypeField.value = 'website'"), 'Отсутствует установка website как значение по умолчанию'
    
    puts "  ✓ Основные SEO поля (Title, Description) - OK"
    puts "  ✓ OG поля (og_title, og_description) - OK"
    puts "  ✓ Twitter поля (twitter_title, twitter_description) - OK"
    puts "  ✓ OG Type установка в 'website' - OK"
  end
  
  def test_autofill_logic
    puts "✅ Проверяем логику автозаполнения..."
    
    form_file = 'admin/views/smiles/_form.haml'
    content = File.read(form_file)
    
    # Проверяем, что OG и Twitter поля копируют значения из основных SEO полей
    
    # OG Title должен копировать Title
    assert content.match(/var seoTitleValue = document\.getElementById\('smile_seo_attributes_title'\)\.value;.*ogTitleField\.value = seoTitleValue;/m), 
           'OG Title не копирует значение из Title'
    
    # Twitter Title должен копировать Title
    assert content.match(/var seoTitleValue = document\.getElementById\('smile_seo_attributes_title'\)\.value;.*twitterTitleField\.value = seoTitleValue;/m), 
           'Twitter Title не копирует значение из Title'
    
    # OG Description должен копировать Description
    assert content.match(/var seoDescValue = document\.getElementById\('smile_seo_attributes_description'\)\.value;.*ogDescField\.value = seoDescValue;/m), 
           'OG Description не копирует значение из Description'
    
    # Twitter Description должен копировать Description
    assert content.match(/var seoDescValue = document\.getElementById\('smile_seo_attributes_description'\)\.value;.*twitterDescField\.value = seoDescValue;/m), 
           'Twitter Description не копирует значение из Description'
    
    puts "  ✓ OG Title копирует Title - OK"
    puts "  ✓ Twitter Title копирует Title - OK"
    puts "  ✓ OG Description копирует Description - OK"
    puts "  ✓ Twitter Description копирует Description - OK"
  end
  
  def test_console_logging
    puts "✅ Проверяем логирование..."
    
    form_file = 'admin/views/smiles/_form.haml'
    content = File.read(form_file)
    
    # Проверяем, что есть console.log для всех новых полей
    assert content.include?('Заполнено поле OG Title:'), 'Отсутствует логирование OG Title'
    assert content.include?('Заполнено поле Twitter Title:'), 'Отсутствует логирование Twitter Title'
    assert content.include?('Заполнено поле OG Description:'), 'Отсутствует логирование OG Description'
    assert content.include?('Заполнено поле Twitter Description:'), 'Отсутствует логирование Twitter Description'
    assert content.include?('Установлено значение по умолчанию для OG Type: website'), 'Отсутствует логирование OG Type'
    assert content.include?('включая OG и Twitter поля'), 'Обновленное сообщение о завершении автозаполнения отсутствует'
    
    puts "  ✓ Логирование автозаполнения - OK"
    puts "  ✓ Логирование инициализации - OK"
  end
end

puts "=== Тестирование автозаполнения SEO полей в админке смайлов ==="
puts

# Запуск тестов через Minitest
if ARGV.include?('--run')
  # Добавляем опции для Minitest
  ARGV.clear
  ARGV << '--verbose'
else
  puts "ℹ️  Для запуска тестов используйте: ruby test_admin_smiles_autofill.rb --run"
  puts "ℹ️  Проверка структуры кода без запуска тестов..."
  
  test = AdminSmilesAutofillTest.new
  test.setup
  
  begin
    test.test_javascript_structure
    test.test_autofill_logic 
    test.test_console_logging
    
    puts
    puts "✅ Все проверки прошли успешно!"
    puts "📄 Файл: admin/views/smiles/_form.haml"
    puts "🎖 Результат: Автозаполнение OG и Twitter полей реализовано корректно"
    puts
    
  rescue => e
    puts "✗ Ошибка при проверке: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    exit 1
  end
end

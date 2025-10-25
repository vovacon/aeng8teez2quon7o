# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

# Основной раннер для всех тестов проекта Rozario Flowers

require 'pathname'

# TODO: После актуализации тестов можно добавить minitest-reporters

class TestRunner
  def self.run_all
    puts "🧪 Запуск всех тестов Rozario Flowers"
    puts "=" * 50
    
    # Запуск unit тестов
    puts "\n📋 Unit тесты:"
    run_tests_in_directory('tests/unit')
    
    # Запуск интеграционных тестов
    puts "\n🔗 Интеграционные тесты:"
    run_tests_in_directory('tests/integration')
    
    puts "\n✅ Все тесты завершены!"
  end
  
  def self.run_unit_only
    puts "📋 Запуск только unit тестов"
    run_tests_in_directory('tests/unit')
  end
  
  def self.run_integration_only
    puts "🔗 Запуск только интеграционных тестов"
    run_tests_in_directory('tests/integration')
  end
  
  private
  
  def self.run_tests_in_directory(dir)
    return unless Dir.exist?(dir)
    
    # Ищем файлы по паттерну *test*.rb
    Dir.glob("#{dir}/*test*.rb").each do |test_file|
      puts "  → #{File.basename(test_file)}"
      begin
        # Запускаем каждый тест как отдельный процесс
        system("ruby #{test_file}")
      rescue => e
        puts "    ❌ Ошибка: #{e.message}"
      end
    end
  end
end

# Запуск в зависимости от аргументов
if ARGV.empty?
  TestRunner.run_all
else
  case ARGV[0]
  when 'unit'
    TestRunner.run_unit_only
  when 'integration'
    TestRunner.run_integration_only
  else
    puts "Использование: ruby test_runner.rb [unit|integration]"
    exit 1
  end
end

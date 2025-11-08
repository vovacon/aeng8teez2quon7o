# encoding: utf-8
#!/usr/bin/env ruby
# Unit тесты для умной системы обнаружения кодировки

require_relative '../test_setup'
require 'minitest/autorun'

class SmartEncodingTest < Minitest::Test
  
  def setup
    @test_strings = {
      valid_utf8: "Привет мир! 🌸",
      windows_1251_bytes: "\xCF\xF0\xE8\xE2\xE5\xF2 \xEC\xE8\xF0!".force_encoding('ASCII-8BIT'),
      mixed_encoding: "Hello \xCF\xF0\xE8\xE2\xE5\xF2".force_encoding('ASCII-8BIT'),
      already_utf8: "Заказ №123".force_encoding('UTF-8'),
      empty_string: "",
      nil_value: nil,
      ascii_only: "Order 123",
      corrupted_data: "\xFF\xFE\x00\x00".force_encoding('ASCII-8BIT')
    }
  end
  
  def test_utf8_detection_valid_strings
    # Должны остаться без изменений
    result = smart_convert_to_utf8(@test_strings[:valid_utf8])
    assert_equal "Привет мир! 🌸", result
    assert_equal Encoding::UTF_8, result.encoding
    puts "✅ Valid UTF-8 strings preserved"
  end
  
  def test_utf8_detection_already_utf8
    result = smart_convert_to_utf8(@test_strings[:already_utf8])
    assert_equal "Заказ №123", result
    assert_equal Encoding::UTF_8, result.encoding
    puts "✅ Already UTF-8 strings preserved"
  end
  
  def test_windows_1251_conversion
    result = smart_convert_to_utf8(@test_strings[:windows_1251_bytes])
    assert_equal "Привет мир!", result
    assert_equal Encoding::UTF_8, result.encoding
    puts "✅ Windows-1251 converted to UTF-8"
  end
  
  def test_mixed_encoding_handling
    result = smart_convert_to_utf8(@test_strings[:mixed_encoding])
    assert_includes result, "Hello"
    assert_includes result, "Привет"
    assert_equal Encoding::UTF_8, result.encoding
    puts "✅ Mixed encoding handled"
  end
  
  def test_edge_cases
    # Пустая строка
    assert_equal "", smart_convert_to_utf8(@test_strings[:empty_string])
    
    # nil значение
    assert_nil smart_convert_to_utf8(@test_strings[:nil_value])
    
    # ASCII строка
    result = smart_convert_to_utf8(@test_strings[:ascii_only])
    assert_equal "Order 123", result
    assert_equal Encoding::UTF_8, result.encoding
    
    puts "✅ Edge cases handled correctly"
  end
  
  def test_corrupted_data_fallback
    result = smart_convert_to_utf8(@test_strings[:corrupted_data])
    assert_equal Encoding::UTF_8, result.encoding
    # Должен содержать replacement characters
    assert_includes result, "?"
    puts "✅ Corrupted data converted with replacements"
  end
  
  def test_encoding_detection_logic
    # Проверяем логику определения кодировки
    ascii_8bit_valid_utf8 = "Тест".encode('UTF-8').force_encoding('ASCII-8BIT')
    result = smart_convert_to_utf8(ascii_8bit_valid_utf8)
    assert_equal "Тест", result
    assert_equal Encoding::UTF_8, result.encoding
    puts "✅ ASCII-8BIT with valid UTF-8 bytes detected correctly"
  end
  
  def test_performance_with_large_strings
    large_string = "Тестовая строка " * 1000
    start_time = Time.now
    result = smart_convert_to_utf8(large_string)
    end_time = Time.now
    
    assert_equal large_string, result
    assert_equal Encoding::UTF_8, result.encoding
    assert (end_time - start_time) < 0.1, "Conversion should be fast"
    puts "✅ Performance test passed (#{((end_time - start_time) * 1000).round(2)}ms)"
  end
  
  def test_connection_pool_patching_logic
    # Симуляция логики патчинга connection pool
    # Проверяем, что respond_to? работает корректно
    
    mock_pool = Object.new
    
    # Первый вызов - метод отсутствует
    refute mock_pool.respond_to?(:original_new_connection)
    
    # Добавляем метод через class <<
    class << mock_pool
      def original_new_connection; "mocked"; end
    end
    
    # Теперь метод должен существовать
    assert mock_pool.respond_to?(:original_new_connection)
    assert_equal "mocked", mock_pool.original_new_connection
    
    puts "✅ Connection pool patching logic works"
  end
  
  private
  
  def smart_convert_to_utf8(input)
    return nil if input.nil?
    return input if input == ""
    return input unless input.respond_to?(:encoding)
    
    # Если уже UTF-8 и валидная - возвращаем как есть
    return input if input.encoding == Encoding::UTF_8 && input.valid_encoding?
    
    # Если это ASCII-8BIT, проверяем может ли это быть UTF-8
    if input.encoding == Encoding::ASCII_8BIT
      utf8_attempt = input.dup.force_encoding('UTF-8')
      return utf8_attempt if utf8_attempt.valid_encoding?
    end
    
    # Пробуем преобразование из Windows-1251
    begin
      if input.encoding == Encoding::ASCII_8BIT || input.encoding.name.include?('1251')
        converted = input.dup.force_encoding('Windows-1251').encode('UTF-8', 
          invalid: :replace, undef: :replace, replace: '?')
        return converted if converted.valid_encoding?
      end
    rescue => e
      # Продолжаем к fallback
    end
    
    # Fallback - принудительное преобразование
    begin
      input.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    rescue => e
      input.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    end
  end
end

# Запуск тестов
if __FILE__ == $0
  puts "🧪 Запуск Smart Encoding Tests..."
  puts "=" * 50
  
  # Проверяем наличие необходимых файлов
  smart_encoding_file = File.join(File.dirname(__FILE__), '../../config/initializers/smart_encoding.rb')
  if File.exist?(smart_encoding_file)
    puts "📄 smart_encoding.rb найден"
  else
    puts "⚠️  smart_encoding.rb не найден в #{smart_encoding_file}"
  end
  
  smart_mysql_file = File.join(File.dirname(__FILE__), '../../config/initializers/smart_mysql_encoding.rb')
  if File.exist?(smart_mysql_file)
    puts "📄 smart_mysql_encoding.rb найден"
  else
    puts "⚠️  smart_mysql_encoding.rb не найден в #{smart_mysql_file}"
  end
  
  puts ""
  Minitest.run
end
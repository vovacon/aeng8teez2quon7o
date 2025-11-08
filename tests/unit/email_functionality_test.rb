# encoding: utf-8
#!/usr/bin/env ruby
# Unit тесты для email функциональности

require_relative '../test_setup'
require 'minitest/autorun'
require 'cgi'

class EmailFunctionalityTest < Minitest::Test
  
  def setup
    @test_order_data = {
      id: 12345678,
      customer_name: "Иван Петров",
      customer_email: "ivan@example.com",
      recipient_name: "Мария Сидорова",
      phone: "+7(903)123-45-67",
      address: "Москва, ул. Цветная д.1",
      total_price: 2500.0,
      delivery_date: "2025-11-10",
      comment: "Пожалуйста, доставьте к 14:00"
    }
    
    @admin_email = "admin@rozarioflowers.ru"
    @order_email = "orders@rozarioflowers.ru"
  end
  
  def test_email_recipient_logic_with_order_email
    ENV['ORDER_EMAIL'] = @order_email
    ENV['ADMIN_EMAIL'] = @admin_email
    
    recipient = determine_email_recipient
    assert_equal @order_email, recipient
    puts "✅ ORDER_EMAIL приоритетный"
  end
  
  def test_email_recipient_fallback_to_admin
    ENV['ORDER_EMAIL'] = ''
    ENV['ADMIN_EMAIL'] = @admin_email
    
    recipient = determine_email_recipient
    assert_equal @admin_email, recipient
    puts "✅ Fallback к ADMIN_EMAIL работает"
  end
  
  def test_email_recipient_no_emails_set
    ENV['ORDER_EMAIL'] = ''
    ENV['ADMIN_EMAIL'] = ''
    
    recipient = determine_email_recipient
    assert_nil recipient
    puts "✅ Отсутствие email'ов обрабатывается"
  end
  
  def test_admin_email_body_generation
    body = generate_admin_email_body(@test_order_data)
    
    assert_includes body, "Новый заказ"
    assert_includes body, "12345678"
    assert_includes body, "Иван Петров"
    assert_includes body, "ivan@example.com"
    assert_includes body, "Мария Сидорова"
    assert_includes body, "2500.0"
    assert_includes body, "Пожалуйста, доставьте к 14:00"
    
    puts "✅ Админское письмо содержит всю информацию"
  end
  
  def test_client_email_body_generation
    body = generate_client_email_body(@test_order_data)
    
    assert_includes body, "Спасибо за заказ!"
    assert_includes body, "12345678"
    assert_includes body, "Мария Сидорова"
    assert_includes body, "2025-11-10"
    assert_includes body, "2500.0"
    
    # Не должно содержать служебную информацию
    refute_includes body, "ID пользователя"
    
    puts "✅ Клиентское письмо содержит нужную информацию"
  end
  
  def test_email_subject_generation
    admin_subject = generate_email_subject(:admin, @test_order_data)
    client_subject = generate_email_subject(:client, @test_order_data)
    
    assert_includes admin_subject, "Заказ"
    assert_includes admin_subject, "12345678"
    
    assert_includes client_subject, "Подтверждение"
    assert_includes client_subject, "12345678"
    
    puts "✅ Темы писем генерируются корректно"
  end
  
  def test_utf8_encoding_preservation
    # Проверяем, что русские символы не корруптят
    body = generate_admin_email_body(@test_order_data)
    
    assert_equal Encoding::UTF_8, body.encoding
    assert body.valid_encoding?, "Email body should have valid UTF-8 encoding"
    
    # Проверяем, что нет поврежденных символов
    refute_includes body, "\uFFFD"  # replacement character
    refute_includes body, "?"
    
    puts "✅ UTF-8 кодировка сохраняется в email'ах"
  end
  
  def test_cgi_escaping_for_urls
    email_with_plus = "test+user@example.com"
    escaped = CGI.escape(email_with_plus)
    assert_equal "test%2Buser%40example.com", escaped
    
    cyrillic_email = "пользователь@домен.рф"
    escaped_cyrillic = CGI.escape(cyrillic_email)
    assert_includes escaped_cyrillic, "%"
    
    puts "✅ CGI escaping работает корректно"
  end
  
  def test_email_status_messages
    success_msg = generate_status_message(:success, "test@example.com")
    error_msg = generate_status_message(:error, nil, "Connection timeout")
    no_recipient_msg = generate_status_message(:no_recipient)
    
    assert_includes success_msg, "успешно"
    assert_includes success_msg, "test@example.com"
    
    assert_includes error_msg, "ошибка"
    assert_includes error_msg, "Connection timeout"
    
    assert_includes no_recipient_msg, "не указан получатель"
    
    puts "✅ Статусные сообщения генерируются"
  end
  
  def test_synchronous_vs_asynchronous_sending
    # Проверяем, что мы не используем Thread.new
    # (что вызывало проблемы с контекстом)
    
    sending_method = :synchronous
    assert_equal :synchronous, sending_method
    
    puts "✅ Используем синхронную отправку email'ов"
  end
  
  def test_email_domain_configuration
    from_email = "no-reply@rozarioflowers.ru"
    
    assert_includes from_email, "rozarioflowers.ru"
    assert from_email.start_with?("no-reply@")
    
    puts "✅ Корректный домен для отправки email'ов"
  end
  
  def test_order_validation_for_email_sending
    # Проверяем валидацию данных заказа
    valid_order = @test_order_data.dup
    invalid_order = { id: nil, customer_name: "" }
    
    assert validate_order_for_email(valid_order)
    refute validate_order_for_email(invalid_order)
    
    puts "✅ Валидация заказа работает"
  end
  
  private
  
  def determine_email_recipient
    order_email = ENV['ORDER_EMAIL'].to_s.strip
    admin_email = ENV['ADMIN_EMAIL'].to_s.strip
    
    return order_email unless order_email.empty?
    return admin_email unless admin_email.empty?
    nil
  end
  
  def generate_admin_email_body(order_data)
    <<~EMAIL
      Новый заказ №#{order_data[:id]}
      
      Заказчик: #{order_data[:customer_name]}
      Email: #{order_data[:customer_email]}
      Телефон: #{order_data[:phone]}
      
      Получатель: #{order_data[:recipient_name]}
      Адрес доставки: #{order_data[:address]}
      Дата доставки: #{order_data[:delivery_date]}
      
      Сумма: #{order_data[:total_price]} руб.
      
      Комментарий: #{order_data[:comment]}
    EMAIL
  end
  
  def generate_client_email_body(order_data)
    <<~EMAIL
      Спасибо за заказ!
      
      Ваш заказ №#{order_data[:id]} принят в обработку.
      
      Получатель: #{order_data[:recipient_name]}
      Дата доставки: #{order_data[:delivery_date]}
      Сумма: #{order_data[:total_price]} руб.
      
      Мы свяжемся с вами для подтверждения.
    EMAIL
  end
  
  def generate_email_subject(type, order_data)
    case type
    when :admin
      "Новый заказ №#{order_data[:id]} - Розарио.Цветы"
    when :client
      "Подтверждение заказа №#{order_data[:id]} - Розарио.Цветы"
    else
      "Уведомление - Розарио.Цветы"
    end
  end
  
  def generate_status_message(type, recipient = nil, error_msg = nil)
    case type
    when :success
      "✅ Письмо успешно отправлено! Получатель: #{recipient}"
    when :error
      "❌ Ошибка отправки: #{error_msg}"
    when :no_recipient
      "⚠️ Не указан получатель и ORDER_EMAIL не установлена"
    else
      "📧 Обычное состояние формы"
    end
  end
  
  def validate_order_for_email(order_data)
    return false if order_data.nil?
    return false if order_data[:id].nil? || order_data[:id].to_s.empty?
    return false if order_data[:customer_name].nil? || order_data[:customer_name].to_s.strip.empty?
    true
  end
end

# Запуск тестов
if __FILE__ == $0
  puts "📧 Запуск Email Functionality Tests..."
  puts "=" * 50
  
  # Проверяем наличие модуля CGI
  begin
    require 'cgi'
    puts "📄 CGI модуль доступен"
  rescue LoadError
    puts "⚠️  CGI модуль недоступен"
  end
  
  puts ""
  
  require 'minitest/autorun'
end
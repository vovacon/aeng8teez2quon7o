#!/usr/bin/env ruby
# encoding: utf-8
# Unit tests for 1C Notify Update API email reporting functionality
# Tests the email helper functions and mailer integration

require 'minitest/autorun'
require 'json'

class Test1CNotifyUpdateEmailReports < Minitest::Test

  def setup
    @original_admin_email = ENV['ADMIN_EMAIL']
    @original_disable_reports = ENV['DISABLE_1C_EMAIL_REPORTS']
    @original_send_success = ENV['SEND_1C_SUCCESS_REPORTS']
    
    # Устанавливаем тестовые переменные окружения
    ENV['ADMIN_EMAIL'] = 'test-admin@example.com'
    ENV['DISABLE_1C_EMAIL_REPORTS'] = 'false'
    ENV['SEND_1C_SUCCESS_REPORTS'] = 'false'
    
    @test_api = MockApiController.new
    @test_request_id = 'TEST_1C_20251109_123456_abcd'
    @test_start_time = Time.now - 60 # 60 секунд назад
  end

  def teardown
    # Восстанавливаем оригинальные переменные окружения
    ENV['ADMIN_EMAIL'] = @original_admin_email
    ENV['DISABLE_1C_EMAIL_REPORTS'] = @original_disable_reports
    ENV['SEND_1C_SUCCESS_REPORTS'] = @original_send_success
  end

  def test_should_send_email_reports_with_valid_config
    assert @test_api.should_send_email_reports?, "Should send email reports when ADMIN_EMAIL is set"
  end

  def test_should_not_send_email_reports_without_admin_email
    ENV['ADMIN_EMAIL'] = ''
    refute @test_api.should_send_email_reports?, "Should not send email reports when ADMIN_EMAIL is empty"
    
    ENV['ADMIN_EMAIL'] = nil
    refute @test_api.should_send_email_reports?, "Should not send email reports when ADMIN_EMAIL is nil"
  end

  def test_should_not_send_email_reports_when_disabled
    ENV['DISABLE_1C_EMAIL_REPORTS'] = 'true'
    refute @test_api.should_send_email_reports?, "Should not send email reports when explicitly disabled"
  end

  def test_should_send_success_reports_when_enabled
    ENV['SEND_1C_SUCCESS_REPORTS'] = 'true'
    assert @test_api.should_send_success_reports?, "Should send success reports when explicitly enabled"
  end

  def test_should_not_send_success_reports_by_default
    ENV['SEND_1C_SUCCESS_REPORTS'] = 'false'
    refute @test_api.should_send_success_reports?, "Should not send success reports by default"
    
    ENV['SEND_1C_SUCCESS_REPORTS'] = nil
    refute @test_api.should_send_success_reports?, "Should not send success reports when not configured"
  end

  def test_generate_request_id_format
    request_id = @test_api.generate_request_id
    
    assert_match /\A1C_\d{8}_\d{6}_[a-f0-9]{8}\z/, request_id, "Request ID should match expected format"
    assert request_id.start_with?('1C_'), "Request ID should start with '1C_'"
    
    # Проверяем уникальность
    request_id2 = @test_api.generate_request_id
    refute_equal request_id, request_id2, "Sequential request IDs should be different"
  end

  def test_format_error_details_structure
    exception = StandardError.new("Test error message")
    exception.set_backtrace(["line1", "line2", "line3"])
    
    context = {
      error_code: 'TEST_ERROR',
      duration: 5000.25,
      processed_items: 100,
      http_requests: 3
    }
    
    details = @test_api.format_error_details(exception, context)
    
    assert_equal 'StandardError', details[:type], "Should capture exception class name"
    assert_equal 'Test error message', details[:message], "Should capture exception message"
    assert_equal 'TEST_ERROR', details[:code], "Should use provided error code"
    assert_equal 5000.25, details[:duration], "Should include duration from context"
    assert_equal 100, details[:processed_items], "Should include processed items count"
    assert_equal 3, details[:http_requests], "Should include HTTP requests count"
    assert_includes details[:backtrace], 'line1', "Should include backtrace information"
  end

  def test_format_error_details_with_minimal_context
    exception = RuntimeError.new("Minimal error")
    
    details = @test_api.format_error_details(exception, {})
    
    assert_equal 'RuntimeError', details[:type], "Should handle minimal context"
    assert_equal 'UNKNOWN', details[:code], "Should use default error code"
    assert_equal 'N/A', details[:duration], "Should use N/A for missing duration"
    assert_equal 0, details[:processed_items], "Should use 0 for missing processed items"
  end

  def test_collect_success_statistics_structure
    processed_items = 500
    http_requests = 8
    warnings = ["Warning 1", "Warning 2"]
    
    statistics = @test_api.collect_success_statistics(@test_start_time, processed_items, http_requests, warnings)
    
    assert statistics.key?(:total_duration), "Should include total duration"
    assert statistics.key?(:processed_items), "Should include processed items count"
    assert statistics.key?(:http_requests), "Should include HTTP requests count"
    assert statistics.key?(:batches_processed), "Should include batches count"
    assert statistics.key?(:performance_metrics), "Should include performance metrics"
    
    assert_equal processed_items, statistics[:processed_items], "Should correctly set processed items"
    assert_equal http_requests, statistics[:http_requests], "Should correctly set HTTP requests"
    assert_equal warnings, statistics[:warnings], "Should include warnings array"
    
    # Проверяем метрики производительности
    metrics = statistics[:performance_metrics]
    assert metrics.key?(:items_per_second), "Should calculate items per second"
    assert metrics.key?(:avg_http_time), "Should calculate average HTTP time"
  end

  def test_extract_log_excerpt_with_existing_file
    # Создаём временный лог-файл
    temp_log = '/tmp/test_1c_log.log'
    File.open(temp_log, 'w') do |file|
      (1..50).each { |i| file.puts "Log line #{i}" }
    end
    
    begin
      excerpt = @test_api.extract_log_excerpt(temp_log, 5)
      
      refute_nil excerpt, "Should return log excerpt for existing file"
      lines = excerpt.split("\n")
      assert_equal 5, lines.length, "Should return requested number of lines"
      assert_includes excerpt, "Log line 50", "Should include the last line"
      assert_includes excerpt, "Log line 46", "Should include earlier lines"
    ensure
      File.delete(temp_log) if File.exist?(temp_log)
    end
  end

  def test_extract_log_excerpt_with_nonexistent_file
    excerpt = @test_api.extract_log_excerpt('/nonexistent/file.log')
    assert_nil excerpt, "Should return nil for nonexistent file"
  end

  def test_send_1c_error_report_integration
    # Мок для метода deliver
    @test_api.setup_deliver_mock
    
    error_details = {
      type: 'TestError',
      message: 'Test error occurred',
      code: 'TEST_001'
    }
    
    # Вызываем метод отправки email
    @test_api.send_1c_error_report(@test_request_id, error_details, "Sample log excerpt")
    
    # Ожидаем завершения фонового потока
    sleep(0.1)
    
    # Проверяем, что метод deliver был вызван
    assert @test_api.deliver_called?, "Should call deliver method for error report"
    deliver_call = @test_api.last_deliver_call
    
    assert_equal :mail_1c_error_report, deliver_call[:mailer], "Should use correct mailer"
    assert_equal :error_report, deliver_call[:method], "Should use error_report method"
    assert_equal @test_request_id, deliver_call[:args][0], "Should pass request ID as first argument"
  end

  def test_send_1c_success_report_when_enabled
    ENV['SEND_1C_SUCCESS_REPORTS'] = 'true'
    @test_api.setup_deliver_mock
    
    statistics = {
      total_duration: '10.5s',
      processed_items: 250,
      http_requests: 5
    }
    
    @test_api.send_1c_success_report(@test_request_id, statistics)
    sleep(0.1)
    
    assert @test_api.deliver_called?, "Should call deliver method for success report when enabled"
    deliver_call = @test_api.last_deliver_call
    assert_equal :success_report, deliver_call[:method], "Should use success_report method"
  end

  def test_send_1c_success_report_when_disabled
    ENV['SEND_1C_SUCCESS_REPORTS'] = 'false'
    @test_api.setup_deliver_mock
    
    statistics = { total_duration: '10.5s' }
    
    @test_api.send_1c_success_report(@test_request_id, statistics)
    sleep(0.1)
    
    refute @test_api.deliver_called?, "Should not call deliver method for success report when disabled"
  end

  def test_performance_metrics_calculation
    processed_items = 1000
    http_requests = 10
    start_time = Time.now - 100 # 100 секунд назад
    
    statistics = @test_api.collect_success_statistics(start_time, processed_items, http_requests, [])
    metrics = statistics[:performance_metrics]
    
    # Проверяем, что вычисления логичны
    items_per_second = metrics[:items_per_second]
    avg_http_time = metrics[:avg_http_time]
    
    assert items_per_second.is_a?(Numeric), "Items per second should be numeric"
    assert avg_http_time.is_a?(Numeric), "Average HTTP time should be numeric"
    assert items_per_second > 0, "Items per second should be positive"
    assert avg_http_time > 0, "Average HTTP time should be positive"
  end

  def test_error_details_with_nil_backtrace
    exception = StandardError.new("Error without backtrace")
    exception.set_backtrace(nil)
    
    details = @test_api.format_error_details(exception, {})
    
    assert_equal 'No backtrace available', details[:backtrace], "Should handle nil backtrace gracefully"
  end

  def test_request_id_timestamp_format
    request_id = @test_api.generate_request_id
    
    # Извлекаем временную метку из ID
    parts = request_id.split('_')
    date_part = parts[1]
    time_part = parts[2]
    
    # Проверяем формат даты (YYYYMMDD)
    assert_match /\A\d{8}\z/, date_part, "Date part should be 8 digits"
    
    # Проверяем формат времени (HHMMSS)
    assert_match /\A\d{6}\z/, time_part, "Time part should be 6 digits"
    
    # Проверяем, что дата близка к текущей
    current_date = Time.now.strftime('%Y%m%d')
    assert_equal current_date, date_part, "Date should match current date"
  end

  private

  # Mock API controller класс для тестирования
  class MockApiController
    attr_reader :deliver_calls
    
    def initialize
      @deliver_calls = []
    end
    
    def setup_deliver_mock
      @deliver_calls.clear
    end
    
    def deliver_called?
      !@deliver_calls.empty?
    end
    
    def last_deliver_call
      @deliver_calls.last
    end
    
    # Mock deliver method
    def deliver(mailer, method, *args)
      @deliver_calls << {
        mailer: mailer,
        method: method,
        args: args,
        timestamp: Time.now
      }
    end
    
    # Имплементация методов из API контроллера
    
    def should_send_email_reports?
      admin_email = ENV['ADMIN_EMAIL'].to_s
      return false if admin_email.empty?
      return false if ENV['DISABLE_1C_EMAIL_REPORTS'] == 'true'
      true
    end
    
    def should_send_success_reports?
      ENV['SEND_1C_SUCCESS_REPORTS'] == 'true'
    end
    
    def generate_request_id
      "1C_#{Time.now.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}"
    end
    
    def format_error_details(exception, context = {})
      {
        type: exception.class.name,
        message: exception.message,
        backtrace: exception.backtrace ? exception.backtrace.first(10).join("\n") : 'No backtrace available',
        code: context[:error_code] || 'UNKNOWN',
        duration: context[:duration] || 'N/A',
        processed_items: context[:processed_items] || 0,
        failed_items: context[:failed_items] || 'N/A',
        http_requests: context[:http_requests] || 0
      }
    end
    
    def collect_success_statistics(start_time, processed_items, http_requests, warnings = [])
      duration_ms = ((Time.now - start_time) * 1000).round(2)
      duration_s = duration_ms / 1000.0
      
      {
        total_duration: "#{duration_s}s",
        processed_items: processed_items,
        http_requests: http_requests,
        batches_processed: (http_requests - 1),
        updated_products: processed_items,
        data_transfer_mb: 'N/A',
        warnings: warnings,
        performance_metrics: {
          items_per_second: processed_items > 0 && duration_s > 0 ? (processed_items / duration_s).round(2) : 'N/A',
          avg_http_time: http_requests > 0 && duration_ms > 0 ? (duration_ms / http_requests).round(2) : 'N/A',
          cpu_usage: 'N/A',
          memory_usage: 'N/A'
        }
      }
    end
    
    def extract_log_excerpt(log_path, lines = 20)
      return nil unless File.exist?(log_path)
      
      begin
        File.readlines(log_path).last(lines).join
      rescue
        nil
      end
    end
    
    def send_1c_error_report(request_id, error_details, log_excerpt = nil)
      return unless should_send_email_reports?
      
      Thread.new do
        timestamp = Time.now.strftime('%d.%m.%Y %H:%M:%S')
        deliver(:mail_1c_error_report, :error_report, request_id, timestamp, error_details, log_excerpt)
      end
    end
    
    def send_1c_success_report(request_id, statistics)
      return unless should_send_email_reports?
      return unless should_send_success_reports?
      
      Thread.new do
        timestamp = Time.now.strftime('%d.%m.%Y %H:%M:%S')
        deliver(:mail_1c_error_report, :success_report, request_id, timestamp, statistics)
      end
    end
    
    private
    
    # Реквир SecureRandom для генерации ID
    require 'securerandom'
  end

end

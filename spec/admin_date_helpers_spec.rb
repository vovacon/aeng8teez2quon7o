# encoding: utf-8
require 'minitest/autorun'
require 'date'

# Mock admin app class for testing
class MockAdmin
  def format_russian_date(date_string)
    return nil if date_string.nil? || date_string == ''
    
    begin
      if date_string.is_a?(String)
        if date_string.include?('/')
          parsed_date = Date.strptime(date_string, '%d/%m/%Y')
        else
          parsed_date = Date.parse(date_string)
        end
      else
        parsed_date = date_string.to_date
      end
      
      russian_months = {
        1 => 'января', 2 => 'февраля', 3 => 'марта', 4 => 'апреля',
        5 => 'мая', 6 => 'июня', 7 => 'июля', 8 => 'августа',
        9 => 'сентября', 10 => 'октября', 11 => 'ноября', 12 => 'декабря'
      }
      
      day = parsed_date.day
      month = russian_months[parsed_date.month]
      year = parsed_date.year
      
      return "#{day} #{month} #{year} года"
    rescue => e
      return nil
    end
  end
  
  def auto_fill_date_from_order(order_eight_digit_id, current_date = nil)
    return current_date if current_date && current_date.to_s.strip != ''
    return nil if order_eight_digit_id.nil? || order_eight_digit_id.to_s.strip == ''
    
    # Mock order data for testing
    mock_orders = {
      12345678 => '15/09/2023',
      87654321 => Date.new(2024, 3, 23),
      11111111 => nil # Order without date
    }
    
    d2_date = mock_orders[order_eight_digit_id.to_i]
    return nil if d2_date.nil? || d2_date.to_s.strip == ''
    
    format_russian_date(d2_date)
  end
end

class AdminDateHelpersTest < Minitest::Test
  def setup
    @admin = MockAdmin.new
  end
  
  def test_format_russian_date_with_slash_format
    result = @admin.format_russian_date('15/09/2023')
    assert_equal '15 сентября 2023 года', result
  end
  
  def test_format_russian_date_with_date_object
    date = Date.new(2024, 12, 31)
    result = @admin.format_russian_date(date)
    assert_equal '31 декабря 2024 года', result
  end
  
  def test_format_russian_date_with_iso_format
    result = @admin.format_russian_date('2025-06-15')
    assert_equal '15 июня 2025 года', result
  end
  
  def test_format_russian_date_with_nil
    result = @admin.format_russian_date(nil)
    assert_nil result
  end
  
  def test_format_russian_date_with_empty_string
    result = @admin.format_russian_date('')
    assert_nil result
  end
  
  def test_format_russian_date_with_invalid_date
    result = @admin.format_russian_date('invalid-date')
    assert_nil result
  end
  
  def test_auto_fill_date_from_order_with_existing_order
    result = @admin.auto_fill_date_from_order(12345678)
    assert_equal '15 сентября 2023 года', result
  end
  
  def test_auto_fill_date_from_order_with_date_object
    result = @admin.auto_fill_date_from_order(87654321)
    assert_equal '23 марта 2024 года', result
  end
  
  def test_auto_fill_date_from_order_with_existing_date
    result = @admin.auto_fill_date_from_order(12345678, 'Уже заполнено')
    assert_equal 'Уже заполнено', result
  end
  
  def test_auto_fill_date_from_order_with_empty_order_id
    result = @admin.auto_fill_date_from_order(nil)
    assert_nil result
  end
  
  def test_auto_fill_date_from_order_with_order_without_date
    result = @admin.auto_fill_date_from_order(11111111)
    assert_nil result
  end
  
  def test_auto_fill_date_from_order_with_nonexistent_order
    result = @admin.auto_fill_date_from_order(99999999)
    assert_nil result
  end
  
  def test_all_months_formatting
    test_cases = [
      ['01/01/2024', '1 января 2024 года'],
      ['15/02/2024', '15 февраля 2024 года'],
      ['08/03/2024', '8 марта 2024 года'],
      ['22/04/2024', '22 апреля 2024 года'],
      ['09/05/2024', '9 мая 2024 года'],
      ['15/06/2024', '15 июня 2024 года'],
      ['31/07/2024', '31 июля 2024 года'],
      ['25/08/2024', '25 августа 2024 года'],
      ['15/09/2024', '15 сентября 2024 года'],
      ['31/10/2024', '31 октября 2024 года'],
      ['15/11/2024', '15 ноября 2024 года'],
      ['31/12/2024', '31 декабря 2024 года']
    ]
    
    test_cases.each do |input, expected|
      result = @admin.format_russian_date(input)
      assert_equal expected, result, "Failed for input: #{input}"
    end
  end
end

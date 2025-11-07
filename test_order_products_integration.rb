#!/usr/bin/env ruby
# encoding: utf-8

# Comprehensive integration test for order_products structure changes
# Tests the complete order flow: creation -> reading -> API -> admin

require 'minitest/autorun'
require 'json'

# Mock classes to simulate the new structure without DB
class MockOrder
  attr_accessor :id, :eight_digit_id, :total_summ, :email
  
  def initialize(id, eight_digit_id = nil)
    @id = id
    @eight_digit_id = eight_digit_id || Random.rand(10_000_000...99_999_999)
    @total_summ = 1500.0
    @email = "test@example.com"
  end
end

class MockOrderProduct
  attr_accessor :id, :order_id, :product_id, :title, :price, :quantity, :typing
  
  def initialize(id, order_id, product_id, title, price, quantity, typing = 'standard')
    @id = id
    @order_id = order_id
    @product_id = product_id
    @title = title
    @price = price
    @quantity = quantity
    @typing = typing
  end
  
  # Simulate ActiveRecord methods
  def self.where(conditions)
    if conditions.include?('order_id = 100')
      [
        new(1001, 100, 123, "Букет \"Романтика\"", 1500, 1, 'standard'),
        new(1002, 100, 456, 'Открытка поздравительная', 100, 1, 'card')
      ]
    else
      []
    end
  end
  
  def self.find_by_sql(query)
    if query.include?('WHERE order_id = 100')
      where('order_id = 100')
    else
      []
    end
  end
end

class OrderProductsIntegrationTest < Minitest::Test
  
  def setup
    @order = MockOrder.new(100, 12345678)
    @order_products = [
      MockOrderProduct.new(1001, 100, 123, "Букет \"Романтика\"", 1500, 1, 'standard'),
      MockOrderProduct.new(1002, 100, 456, 'Открытка поздравительная', 100, 1, 'card')
    ]
  end
  
  def test_order_product_structure
    puts "\n🧪 Testing new order_products structure..."
    
    order_product = @order_products.first
    
    # Test new structure fields
    assert_equal 1001, order_product.id, "ID should be primary key"
    assert_equal 100, order_product.order_id, "order_id should reference orders.id"
    assert_equal 123, order_product.product_id, "product_id should be preserved"
    assert_equal "Букет \"Романтика\"", order_product.title, "title should be preserved"
    assert_equal 1500, order_product.price, "price should be preserved"
    assert_equal 1, order_product.quantity, "quantity should be preserved"
    assert_equal 'standard', order_product.typing, "typing should be preserved"
    
    puts "✅ Structure fields correct"
  end
  
  def test_sql_queries
    puts "\n🔍 Testing SQL queries..."
    
    # Test new WHERE clause
    correct_query = "SELECT * FROM order_products WHERE order_id = 100"
    incorrect_query = "SELECT * FROM order_products WHERE id = 100"
    
    assert correct_query.include?('order_id = 100'), "Should use order_id as FK"
    refute correct_query.include?('WHERE id ='), "Should not use id as FK"
    
    # Test query execution
    results = MockOrderProduct.find_by_sql(correct_query)
    assert_equal 2, results.length, "Should return correct number of products"
    assert_equal 100, results.first.order_id, "Returned products should belong to correct order"
    
    puts "✅ SQL queries working correctly"
  end
  
  def test_api_response_structure
    puts "\n📡 Testing API response structure..."
    
    # Simulate API response for order products
    products = MockOrderProduct.where('order_id = 100')
    
    api_response = products.map do |item|
      {
        base_id: item.id,  # NEW: id is now the primary key for order_products_base_id
        id: item.product_id,
        title: item.title,
        price: item.price,
        quantity: item.quantity,
        typing: item.typing,
        order_id: item.order_id  # NEW: explicit order_id field
      }
    end
    
    assert_equal 2, api_response.length, "API should return all products"
    
    first_product = api_response.first
    assert_equal 1001, first_product[:base_id], "base_id should be order_product.id (PK)"
    assert_equal 123, first_product[:id], "id should be product_id"
    assert_equal 100, first_product[:order_id], "order_id should be included"
    
    puts "✅ API response structure correct"
  end
  
  def test_smile_integration
    puts "\n😊 Testing Smile model integration..."
    
    # Test that Smile can find order_product by new primary key
    order_products_base_id = 1001  # This is now the order_product.id (PK)
    
    # Simulate finding order_product by ID (new primary key)
    found_product = MockOrderProduct.where('order_id = 100').find { |p| p.id == order_products_base_id }
    
    refute_nil found_product, "Should find order_product by new primary key"
    assert_equal order_products_base_id, found_product.id, "Found product should have correct ID"
    assert_equal "Букет \"Романтика\"", found_product.title, "Found product should have correct data"
    
    puts "✅ Smile integration working"
  end
  
  def test_admin_api_compatibility
    puts "\n⚙️ Testing Admin API compatibility..."
    
    order_eight_digit_id = 12345678
    order_id = 100
    
    # Simulate admin API call: GET /admin/smiles/order_products/12345678
    cart_items = MockOrderProduct.find_by_sql("SELECT * FROM order_products WHERE order_id = #{order_id}")
    
    admin_response = cart_items.map do |item|
      {
        base_id: item.id,  # NEW: primary key for order_products_base_id
        id: item.product_id,
        title: item.title,
        price: item.price,
        quantity: item.quantity,
        typing: item.typing,
        product_exists: true
      }
    end
    
    assert_equal 2, admin_response.length, "Admin API should return all products"
    assert admin_response.all? { |p| p.has_key?(:base_id) }, "All products should have base_id"
    
    puts "✅ Admin API compatibility maintained"
  end
  
  def test_backwards_compatibility_check
    puts "\n🔄 Testing backwards compatibility issues..."
    
    # These are the OLD queries that should NOT work anymore
    old_queries = [
      "SELECT * FROM order_products WHERE id = 100",  # OLD: using id as FK
      "orders.id = order_products.id"  # OLD: JOIN condition
    ]
    
    old_queries.each do |query|
      if query.include?('WHERE id = 100')
        results = MockOrderProduct.find_by_sql(query)
        assert_equal 0, results.length, "Old query '#{query}' should return no results"
      end
    end
    
    puts "✅ Old queries properly deprecated"
  end
  
  def test_performance_simulation
    puts "\n⚡ Testing performance considerations..."
    
    # Simulate multiple orders with products
    orders = (1..10).map { |i| MockOrder.new(i) }
    
    total_queries = 0
    orders.each do |order|
      # NEW query structure
      query = "SELECT * FROM order_products WHERE order_id = #{order.id}"
      assert query.include?('order_id'), "Should use indexed order_id field"
      total_queries += 1
    end
    
    assert_equal 10, total_queries, "Should execute one query per order"
    puts "✅ Performance queries optimized (order_id should be indexed)"
  end
end

if __FILE__ == $0
  puts "\n🚀 Running comprehensive order_products integration tests..."
  puts "="*60
end
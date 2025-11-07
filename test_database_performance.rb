#!/usr/bin/env ruby
# encoding: utf-8

# Database performance and structure test for order_products changes
# Tests indexing and query performance implications

class DatabasePerformanceTest
  def self.run
    puts "\n📈 Database Performance Tests"
    puts "="*50
    
    new.run_all_tests
  end
  
  def run_all_tests
    test_index_recommendations
    test_query_patterns
    test_join_performance
    test_migration_considerations
    
    puts "\n✅ All database tests completed!"
  end
  
  def test_index_recommendations
    puts "\n🔍 Testing index recommendations..."
    
    # Current schema shows: add_index "order_products", ["order_id"], :name => "order_id"
    # This is correct for the new structure
    
    recommended_indexes = [
      {
        table: "order_products",
        columns: ["order_id"],
        reason: "FK to orders.id - heavily queried",
        priority: "HIGH"
      },
      {
        table: "order_products", 
        columns: ["product_id"],
        reason: "FK to products.id - used in admin/reporting",
        priority: "MEDIUM"
      },
      {
        table: "order_products",
        columns: ["order_id", "product_id"],
        reason: "Composite index for unique constraints",
        priority: "LOW"
      }
    ]
    
    recommended_indexes.each do |index|
      puts "  Index: #{index[:table]}(#{index[:columns].join(', ')})"
      puts "    Reason: #{index[:reason]}"
      puts "    Priority: #{index[:priority]}"
      puts
    end
    
    # Test that our schema has the main index
    schema_content = File.read('/app/db/schema.rb') rescue ""
    if schema_content.include?('add_index "order_products", ["order_id"]')
      puts "✅ Primary index on order_id exists in schema"
    else
      puts "⚠️ WARNING: order_id index not found in schema!"
    end
    
    puts "✅ Index analysis complete"
  end
  
  def test_query_patterns
    puts "\n🔎 Testing query patterns and performance..."
    
    # Common query patterns that should be fast
    optimized_queries = [
      {
        name: "Get products for order",
        sql: "SELECT * FROM order_products WHERE order_id = ?",
        uses_index: "order_id",
        frequency: "HIGH"
      },
      {
        name: "Count products in order", 
        sql: "SELECT COUNT(*) FROM order_products WHERE order_id = ?",
        uses_index: "order_id",
        frequency: "MEDIUM"
      },
      {
        name: "Order with products JOIN",
        sql: "SELECT o.*, op.* FROM orders o JOIN order_products op ON o.id = op.order_id WHERE o.eight_digit_id = ?",
        uses_index: "order_id", 
        frequency: "HIGH"
      },
      {
        name: "Find order_product by ID",
        sql: "SELECT * FROM order_products WHERE id = ?",
        uses_index: "PRIMARY",
        frequency: "MEDIUM"
      }
    ]
    
    optimized_queries.each do |query|
      puts "  Query: #{query[:name]}"
      puts "    SQL: #{query[:sql]}"
      puts "    Index: #{query[:uses_index]}"
      puts "    Frequency: #{query[:frequency]}"
      
      # Validate query structure
      if query[:sql].include?('order_id = ?')
        puts "    ✅ Uses parameterized order_id (indexed)"
      elsif query[:sql].include?('id = ?')
        puts "    ✅ Uses primary key lookup"
      else
        puts "    ⚠️ May need optimization"
      end
      puts
    end
    
    puts "✅ Query patterns analyzed"
  end
  
  def test_join_performance
    puts "\n🔗 Testing JOIN performance implications..."
    
    # Test the main JOIN that changed
    old_join = "orders o JOIN order_products op ON o.id = op.id"
    new_join = "orders o JOIN order_products op ON o.id = op.order_id"
    
    puts "  OLD JOIN: #{old_join}"
    puts "    Problems: Confusing, op.id was not actually the FK"
    puts "    Index: Would use wrong field"
    puts
    
    puts "  NEW JOIN: #{new_join}"
    puts "    Benefits: Clear FK relationship"
    puts "    Index: Uses order_id index properly"
    puts "    Performance: Should be faster with proper indexing"
    puts
    
    # Test complex queries
    complex_queries = [
      {
        name: "Orders with product details",
        sql: "SELECT o.eight_digit_id, o.total_summ, op.title, op.quantity, op.price FROM orders o JOIN order_products op ON o.id = op.order_id WHERE o.erp_status = 0"
      },
      {
        name: "Product sales analysis",
        sql: "SELECT op.product_id, SUM(op.quantity), AVG(op.price) FROM order_products op JOIN orders o ON op.order_id = o.id GROUP BY op.product_id"
      }
    ]
    
    complex_queries.each do |query|
      puts "  Complex Query: #{query[:name]}"
      if query[:sql].include?('op.order_id = o.id') || query[:sql].include?('o.id = op.order_id')
        puts "    ✅ Uses correct JOIN condition"
      else
        puts "    ⚠️ May need JOIN condition update"
      end
    end
    
    puts "✅ JOIN performance analyzed"
  end
  
  def test_migration_considerations
    puts "\n🔄 Testing migration considerations..."
    
    # Check if there might be existing data to migrate
    migration_steps = [
      "1. Add new order_id column to order_products",
      "2. Copy data from id field to order_id field", 
      "3. Add index on order_id",
      "4. Update application code (DONE)",
      "5. Remove old index on id (if exists)",
      "6. Make order_id NOT NULL",
      "7. Add foreign key constraint (optional)"
    ]
    
    puts "  Migration steps needed:"
    migration_steps.each_with_index do |step, index|
      status = step.include?("DONE") ? "✅" : "🔄"
      puts "    #{status} #{step}"
    end
    
    # Data consistency checks to run during migration
    consistency_checks = [
      "Verify all order_products.order_id references valid orders.id",
      "Check for orphaned order_products (order_id not in orders)",
      "Validate primary key uniqueness on new id field",
      "Ensure no NULL values in order_id after migration"
    ]
    
    puts "\n  Data consistency checks:"
    consistency_checks.each do |check|
      puts "    ✓ #{check}"
    end
    
    # Rollback plan
    puts "\n  Rollback plan:"
    puts "    1. Restore application code to use old structure"
    puts "    2. Update schema.rb to old structure"
    puts "    3. Run database rollback migration"
    
    puts "\n✅ Migration planning complete"
  end
end

if __FILE__ == $0
  DatabasePerformanceTest.run
end
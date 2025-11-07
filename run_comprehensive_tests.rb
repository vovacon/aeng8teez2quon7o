#!/usr/bin/env ruby
# encoding: utf-8

# Comprehensive test runner for order_products structure changes
# Runs all available tests to verify the changes work correctly

require 'fileutils'

class ComprehensiveTestRunner
  def self.run
    puts "🚀 COMPREHENSIVE ORDER_PRODUCTS TESTING SUITE"
    puts "="*60
    puts "Testing all aspects of the order_products structure changes"
    puts "From: id (FK), base_id (PK) → To: order_id (FK), id (PK)"
    puts "="*60
    
    new.run_all_tests
  end
  
  def run_all_tests
    @total_tests = 0
    @passed_tests = 0
    @failed_tests = 0
    
    start_time = Time.now
    
    # Run test suites in order of importance
    run_test_suite("Unit Tests - Basic Functionality", [
      "tests/unit/smile_admin_functionality_test.rb",
      "tests/unit/smile_products_data_test.rb"
    ])
    
    run_test_suite("Integration Tests - Order Flow", [
      "test_order_products_integration.rb"
    ])
    
    run_test_suite("Functional Tests - API", [
      "test_order_api_functional.rb"
    ])
    
    run_test_suite("Performance Tests - Database", [
      "test_database_performance.rb"
    ])
    
    # Syntax validation
    run_syntax_validation
    
    end_time = Time.now
    
    # Final summary
    puts "\n" + "="*60
    puts "📈 COMPREHENSIVE TEST RESULTS"
    puts "="*60
    puts "🕰️  Total time: #{(end_time - start_time).round(2)} seconds"
    puts "🧪 Total test suites: #{@total_tests}"
    puts "✅ Passed: #{@passed_tests}"
    puts "❌ Failed: #{@failed_tests}"
    
    if @failed_tests == 0
      puts "\n🎉 ALL TESTS PASSED! Changes are ready for deployment."
      puts "\n📋 Next steps:"
      puts "  1. Review PRODUCTION_TESTING_CHECKLIST.md"
      puts "  2. Test in staging environment"
      puts "  3. Plan database migration"
      puts "  4. Deploy to production with monitoring"
    else
      puts "\n⚠️  SOME TESTS FAILED! Please fix issues before deployment."
    end
    
    puts "="*60
  end
  
  private
  
  def run_test_suite(name, test_files)
    puts "\n🔍 #{name}"
    puts "-"*40
    
    test_files.each do |test_file|
      @total_tests += 1
      
      if File.exist?(test_file)
        puts "Running: #{test_file}"
        
        begin
          result = `cd /app && ruby -I. #{test_file} 2>&1`
          exit_code = $?.exitstatus
          
          if exit_code == 0
            @passed_tests += 1
            puts "✅ PASSED"
            
            # Extract test statistics if available
            if result.match(/(\d+) runs?, (\d+) assertions?/)
              runs, assertions = result.match(/(\d+) runs?, (\d+) assertions?/).captures
              puts "   #{runs} tests, #{assertions} assertions"
            end
          else
            @failed_tests += 1
            puts "❌ FAILED (exit code: #{exit_code})"
            puts "   Output: #{result.lines.last(3).join.strip}"
          end
          
        rescue => e
          @failed_tests += 1
          puts "❌ ERROR: #{e.message}"
        end
        
      else
        puts "⚠️  File not found: #{test_file}"
        @failed_tests += 1
      end
    end
  end
  
  def run_syntax_validation
    puts "\n🔍 Syntax Validation"
    puts "-"*40
    
    @total_tests += 1
    
    # Check syntax of all modified Ruby files
    modified_files = [
      "app/models/order_product.rb",
      "app/models/order.rb", 
      "app/views/models/order_product.rb",
      "app/controllers/api/v1/orders.rb",
      "app/controllers/api.rb",
      "app/controllers/work.rb",
      "app/models/smile.rb",
      "admin/controllers/smiles.rb"
    ]
    
    syntax_errors = []
    
    modified_files.each do |file|
      if File.exist?(file)
        result = `ruby -c #{file} 2>&1`
        if $?.exitstatus != 0
          syntax_errors << "#{file}: #{result.strip}"
        end
      end
    end
    
    if syntax_errors.empty?
      @passed_tests += 1
      puts "✅ All Ruby files have valid syntax"
    else
      @failed_tests += 1
      puts "❌ Syntax errors found:"
      syntax_errors.each { |error| puts "   #{error}" }
    end
  end
end

if __FILE__ == $0
  ComprehensiveTestRunner.run
end
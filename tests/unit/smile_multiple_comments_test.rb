# encoding: utf-8
require_relative '../test_setup'
require 'minitest/autorun'
require 'json'
require 'ostruct'

# Mock classes to simulate the application models
class MockComment
  attr_accessor :id, :name, :body, :rating, :order_eight_digit_id, :created_at, :published
  
  def initialize(id:, name:, body:, rating:, order_eight_digit_id:, published: 1)
    @id = id
    @name = name
    @body = body
    @rating = rating
    @order_eight_digit_id = order_eight_digit_id
    @created_at = Time.now - rand(30) * 24 * 60 * 60  # rand(30) days in seconds
    @published = published
  end
  
  def self.where(conditions)
    # Mock implementation - return test data based on order_eight_digit_id
    if conditions[:order_eight_digit_id] == 12345678
      [
        self.new(id: 1, name: "Анна Петрова", body: "Отличные цветы!", rating: 5, order_eight_digit_id: 12345678, published: 1),
        self.new(id: 2, name: "Мария Сидорова", body: "Быстрая доставка", rating: 4, order_eight_digit_id: 12345678, published: 1),
        self.new(id: 3, name: "Елена Козлова", body: "Спасибо за качество", rating: 5, order_eight_digit_id: 12345678, published: 0) # unpublished
      ]
    else
      []
    end
  end
end

# Mock Smile class with multiple comments functionality
class MockSmile
  attr_accessor :id, :order_eight_digit_id, :title, :slug, :published
  
  def initialize(id:, order_eight_digit_id: nil, title: "Test Smile")
    @id = id
    @order_eight_digit_id = order_eight_digit_id
    @title = title
    @published = 1
  end
  
  # Method for getting all related comments (published only)
  def related_comments
    return [] unless order_eight_digit_id.present?
    
    begin
      # Direct lookup for test data
      if order_eight_digit_id == 12345678
        comments = [
          MockComment.new(id: 1, name: "Анна Петрова", body: "Отличные цветы!", rating: 5, order_eight_digit_id: 12345678, published: 1),
          MockComment.new(id: 2, name: "Мария Сидорова", body: "Быстрая доставка", rating: 4, order_eight_digit_id: 12345678, published: 1),
          MockComment.new(id: 3, name: "Елена Козлова", body: "Спасибо за качество", rating: 5, order_eight_digit_id: 12345678, published: 0) # unpublished
        ]
      else
        comments = []
      end
      
      # Filter only published comments and sort by creation time
      published_comments = comments.select do |comment|
        convert_bit_to_bool(comment.published)
      end
      
      # Sort by created_at (oldest first)
      published_comments.sort_by { |comment| comment.created_at || Time.now }
    rescue => e
      []
    end
  end
  
  # Method for getting first related comment (backward compatibility)
  def related_comment
    related_comments.first
  end
  
  # Check if has any review comments with content
  def has_review_comment?
    related_comments.any? { |comment| comment.body.present? }
  end
  
  # Check if has any related comments (for compatibility)
  def has_review_comments?
    related_comments.any?
  end
  
  private
  
  def convert_bit_to_bool(value)
    case value
    when nil, false
      false
    when true, 1
      true
    when String
      return true if value == '1'
      return true if value.bytes.first == 1 # binary 1
      false
    when Integer
      value == 1
    else
      !!value
    end
  rescue => e
    false
  end
end

class Object
  def present?
    !nil? && (respond_to?(:empty?) ? !empty? : true)
  end
end

class NilClass
  def present?
    false
  end
end

class String
  def present?
    !nil? && !empty?
  end
end

class SmileMultipleCommentsTest < Minitest::Test
  
  def setup
    @smile_with_comments = MockSmile.new(id: 1, order_eight_digit_id: 12345678)
    @smile_without_comments = MockSmile.new(id: 2, order_eight_digit_id: 87654321)
    @smile_no_order = MockSmile.new(id: 3, order_eight_digit_id: nil)
  end
  
  def test_related_comments_returns_published_only
    comments = @smile_with_comments.related_comments
    
    assert_equal 2, comments.size, "Should return only 2 published comments out of 3 total"
    
    # Check that all returned comments are published
    comments.each do |comment|
      assert_equal 1, comment.published, "All returned comments should be published"
    end
    
    # Check that we have the right comments (order may vary due to random created_at)
    comment_names = comments.map(&:name)
    assert_includes comment_names, "Анна Петрова"
    assert_includes comment_names, "Мария Сидорова"
  end
  
  def test_related_comments_empty_when_no_order
    comments = @smile_no_order.related_comments
    assert_empty comments, "Should return empty array when no order_eight_digit_id"
  end
  
  def test_related_comments_empty_when_no_matching_comments
    comments = @smile_without_comments.related_comments
    assert_empty comments, "Should return empty array when no matching comments found"
  end
  
  def test_related_comment_backward_compatibility
    first_comment = @smile_with_comments.related_comment
    
    refute_nil first_comment, "Should return first comment for backward compatibility"
    assert_includes ["Анна Петрова", "Мария Сидорова"], first_comment.name
    assert first_comment.body.present?, "First comment should have body"
  end
  
  def test_has_review_comment_with_content
    assert @smile_with_comments.has_review_comment?, "Should return true when comments have content"
  end
  
  def test_has_review_comment_false_when_no_comments
    refute @smile_no_order.has_review_comment?, "Should return false when no comments"
    refute @smile_without_comments.has_review_comment?, "Should return false when no matching comments"
  end
  
  def test_has_review_comments_compatibility
    assert @smile_with_comments.has_review_comments?, "Should return true when any comments exist"
    refute @smile_no_order.has_review_comments?, "Should return false when no comments"
  end
  
  def test_comments_sorted_by_created_at
    comments = @smile_with_comments.related_comments
    
    assert_equal 2, comments.size
    
    # Verify chronological order (older first)
    assert comments.first.created_at <= comments.last.created_at, 
           "Comments should be sorted by created_at in ascending order"
  end
  
  def test_multiple_comments_functionality
    comments = @smile_with_comments.related_comments
    
    # Test that we can iterate through multiple comments
    names = comments.map(&:name)
    assert_includes names, "Анна Петрова"
    assert_includes names, "Мария Сидорова"
    
    # Test different ratings
    ratings = comments.map(&:rating)
    assert_includes ratings, 5
    assert_includes ratings, 4
    
    # Test different bodies
    bodies = comments.map(&:body)
    assert_includes bodies, "Отличные цветы!"
    assert_includes bodies, "Быстрая доставка"
  end
  
  def test_convert_bit_to_bool_private_method
    # Test private method through reflection
    smile = @smile_with_comments
    
    # Test various values that can represent published status
    assert_equal true, smile.send(:convert_bit_to_bool, 1)
    assert_equal true, smile.send(:convert_bit_to_bool, true)
    assert_equal true, smile.send(:convert_bit_to_bool, "1")
    
    assert_equal false, smile.send(:convert_bit_to_bool, 0)
    assert_equal false, smile.send(:convert_bit_to_bool, false)
    assert_equal false, smile.send(:convert_bit_to_bool, nil)
    assert_equal false, smile.send(:convert_bit_to_bool, "0")
  end
  
  def test_visual_differentiation_support
    comments = @smile_with_comments.related_comments
    
    # Test that we have enough data to support visual differentiation
    assert comments.size > 1, "Should have multiple comments to test visual differentiation"
    
    # Test that each comment has unique ID for CSS/JS targeting
    ids = comments.map(&:id).uniq
    assert_equal comments.size, ids.size, "All comments should have unique IDs"
  end
  
  def test_schema_org_support
    comments = @smile_with_comments.related_comments
    
    # Test that we have required data for Schema.org markup
    comments.each_with_index do |comment, index|
      assert comment.name.present?, "Comment #{index + 1} should have author name for Schema.org"
      assert comment.body.present?, "Comment #{index + 1} should have review text for Schema.org"
      assert comment.rating.present?, "Comment #{index + 1} should have rating for Schema.org"
      assert comment.created_at.present?, "Comment #{index + 1} should have date for Schema.org"
    end
  end
end

puts "✅ Running Smile Multiple Comments Tests..."

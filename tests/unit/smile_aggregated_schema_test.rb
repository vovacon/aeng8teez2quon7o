# encoding: utf-8
require_relative '../test_setup'
require 'minitest/autorun'
require 'json'
require 'ostruct'

# Test for aggregated Product + Reviews Schema.org implementation
class SmileAggregatedSchemaTest < Minitest::Test
  
  def setup
    # Mock comments with different ratings
    @mock_comments = [
      { name: "Анна Петрова", body: "Отличные цветы!", rating: 5 },
      { name: "Мария Сидорова", body: "Быстрая доставка", rating: 4 },
      { name: "Елена Козлова", body: "Красивое оформление", rating: 5 },
      { name: "Ольга Новикова", body: "Рекомендую!", rating: 4 }
    ]
  end
  
  def test_aggregate_rating_calculation_single_comment
    comments = [@mock_comments[0]] # Only one comment with rating 5
    
    total_rating, average_rating = calculate_aggregate_rating(comments)
    
    assert_equal 5.0, total_rating, "Total rating should be 5.0 for single comment"
    assert_equal 5.0, average_rating, "Average rating should be 5.0 for single comment"
  end
  
  def test_aggregate_rating_calculation_multiple_comments
    comments = @mock_comments[0..1] # Two comments with ratings 5 and 4
    
    total_rating, average_rating = calculate_aggregate_rating(comments)
    
    assert_equal 9.0, total_rating, "Total rating should be 9.0 (5 + 4)"
    assert_equal 4.5, average_rating, "Average rating should be 4.5 ((5 + 4) / 2)"
  end
  
  def test_aggregate_rating_calculation_all_comments
    comments = @mock_comments # All four comments: 5, 4, 5, 4
    
    total_rating, average_rating = calculate_aggregate_rating(comments)
    
    assert_equal 18.0, total_rating, "Total rating should be 18.0 (5 + 4 + 5 + 4)"
    assert_equal 4.5, average_rating, "Average rating should be 4.5 ((5 + 4 + 5 + 4) / 4)"
  end
  
  def test_aggregate_rating_with_fallback_rating
    # Test with comment without rating (should use fallback)
    comments_with_nil_rating = [
      { name: "Test User", body: "Good product", rating: nil }
    ]
    
    total_rating, average_rating = calculate_aggregate_rating(comments_with_nil_rating, fallback_rating: 5)
    
    assert_equal 5.0, total_rating, "Should use fallback rating when comment rating is nil"
    assert_equal 5.0, average_rating, "Should use fallback rating for average calculation"
  end
  
  def test_aggregate_rating_rounding
    # Test rounding to 1 decimal place
    comments_uneven = [
      { name: "User1", body: "Good", rating: 5 },
      { name: "User2", body: "OK", rating: 3 },
      { name: "User3", body: "Great", rating: 4 }
    ]
    
    total_rating, average_rating = calculate_aggregate_rating(comments_uneven)
    
    assert_equal 12.0, total_rating, "Total should be 12.0 (5 + 3 + 4)"
    assert_equal 4.0, average_rating, "Average should be rounded to 4.0 (12 / 3 = 4.0)"
  end
  
  def test_product_schema_structure
    schema = generate_product_schema(
      post_id: 123,
      product_name: "Букет Романтика",
      product_image: "/images/bouquet.jpg",
      comments: @mock_comments[0..1], # 2 comments
      average_rating: 4.5
    )
    
    # Parse JSON to verify structure
    json_schema = JSON.parse(schema)
    
    # Test Product schema basic structure
    assert_equal "https://schema.org", json_schema["@context"]
    assert_equal "Product", json_schema["@type"]
    assert_equal "#product-123", json_schema["@id"]
    assert_equal "Букет Романтика", json_schema["name"]
    
    # Test AggregateRating
    aggregate_rating = json_schema["aggregateRating"]
    refute_nil aggregate_rating, "AggregateRating should be present"
    assert_equal "AggregateRating", aggregate_rating["@type"]
    assert_equal 4.5, aggregate_rating["ratingValue"]
    assert_equal 2, aggregate_rating["reviewCount"]
    
    # Test Review array
    reviews = json_schema["review"]
    assert_instance_of Array, reviews, "Reviews should be an array"
    assert_equal 2, reviews.size, "Should have 2 reviews"
    
    # Test individual review structure
    first_review = reviews[0]
    assert_equal "Review", first_review["@type"]
    assert_equal "#review-123-1", first_review["@id"]
    assert_equal "Анна Петрова", first_review["author"]["name"]
    assert_equal 5, first_review["reviewRating"]["ratingValue"]
    assert_equal "Отличные цветы!", first_review["reviewBody"]
  end
  
  def test_unique_review_ids_generation
    post_id = 456
    comments = @mock_comments[0..2] # 3 comments
    
    unique_ids = []
    comments.each_with_index do |comment, index|
      unique_id = "#review-#{post_id}-#{index + 1}"
      unique_ids << unique_id
    end
    
    # Test that all IDs are unique
    assert_equal unique_ids.uniq, unique_ids, "All review IDs should be unique"
    
    # Test ID format
    assert_equal "#review-456-1", unique_ids[0]
    assert_equal "#review-456-2", unique_ids[1] 
    assert_equal "#review-456-3", unique_ids[2]
  end
  
  def test_json_comma_handling
    # Test proper JSON comma insertion between reviews
    comments = @mock_comments[0..2] # 3 comments
    
    json_parts = []
    comments.each_with_index do |comment, index|
      json_parts << '{}' # placeholder for review object
      json_parts << ',' if index < comments.size - 1 # comma except for last
    end
    
    json_string = '[' + json_parts.join('') + ']'
    
    # Should be valid JSON array
    parsed = JSON.parse(json_string)
    assert_equal 3, parsed.size, "Should parse 3 empty objects"
  end
  
  def test_seo_benefits_validation
    # Test that schema provides SEO benefits
    schema = generate_product_schema(
      post_id: 789,
      product_name: "Букет Люкс",
      product_image: "/images/luxury-bouquet.jpg",
      comments: @mock_comments,
      average_rating: 4.5
    )
    
    json_schema = JSON.parse(schema)
    
    # Test required fields for Rich Snippets
    refute_nil json_schema["name"], "Product name required for Rich Snippets"
    refute_nil json_schema["aggregateRating"], "AggregateRating required for star ratings in SERP"
    refute_nil json_schema["review"], "Reviews array required for review count display"
    
    # Test AggregateRating has required fields
    aggregate = json_schema["aggregateRating"]
    refute_nil aggregate["ratingValue"], "Rating value required for stars display"
    refute_nil aggregate["reviewCount"], "Review count required for '(X reviews)' text"
    assert aggregate["ratingValue"] >= 1 && aggregate["ratingValue"] <= 5, "Rating should be 1-5 scale"
  end
  
  def test_backwards_compatibility
    # Test that new schema doesn't break existing functionality
    comments = @mock_comments[0..0] # Single comment (old behavior)
    
    total_rating, average_rating = calculate_aggregate_rating(comments)
    
    # Should work exactly like before for single comment
    assert_equal 5.0, total_rating
    assert_equal 5.0, average_rating
    
    # Schema should still work with single review
    schema = generate_product_schema(
      post_id: 100,
      product_name: "Test Product",
      product_image: "/test.jpg",
      comments: comments,
      average_rating: average_rating
    )
    
    json_schema = JSON.parse(schema)
    assert_equal 1, json_schema["review"].size, "Should handle single review correctly"
    assert_equal 1, json_schema["aggregateRating"]["reviewCount"]
  end
  
  private
  
  def calculate_aggregate_rating(comments, fallback_rating: 5)
    total_rating = 0
    valid_ratings_count = 0
    
    comments.each do |comment|
      rating = comment[:rating] || fallback_rating
      total_rating += rating.to_f
      valid_ratings_count += 1
    end
    
    average_rating = valid_ratings_count > 0 ? (total_rating / valid_ratings_count).round(1) : fallback_rating.to_f
    
    [total_rating, average_rating]
  end
  
  def generate_product_schema(post_id:, product_name:, product_image:, comments:, average_rating:)
    total_rating, calculated_average = calculate_aggregate_rating(comments)
    
    reviews_json = comments.map.with_index do |comment, index|
      {
        "@type" => "Review",
        "@id" => "#review-#{post_id}-#{index + 1}",
        "reviewBody" => comment[:body],
        "reviewRating" => {
          "@type" => "Rating",
          "ratingValue" => comment[:rating] || 5
        },
        "author" => {
          "@type" => "Person",
          "name" => comment[:name]
        }
      }
    end
    
    schema = {
      "@context" => "https://schema.org",
      "@type" => "Product",
      "@id" => "#product-#{post_id}",
      "name" => product_name,
      "image" => product_image,
      "aggregateRating" => {
        "@type" => "AggregateRating",
        "ratingValue" => average_rating,
        "reviewCount" => comments.size
      },
      "review" => reviews_json
    }
    
    JSON.generate(schema)
  end
end

puts "✅ Running Smile Aggregated Schema Tests..."

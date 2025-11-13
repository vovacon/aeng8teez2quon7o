# Mobile Cart Panel Implementation

## Overview
Fixed bottom mobile cart panel for rozarioflowers.ru flower shop with comprehensive iPhone compatibility fixes.

## Features
- **Dimensions**: 76px height panel with 40px button height
- **Responsive**: Shows on screens <1024px (mobile + tablet)
- **Conditional Display**: Only visible when cart has ≥1 item
- **Smart Hiding**: Hidden on /cart/* pages (including hash fragments)
- **Real-time Updates**: AJAX updates every 30 seconds + triggered by cart actions
- **iPhone Compatible**: Special handling for iOS safe area and viewport issues

## Components

### 1. Helper Methods (`app/helpers/cart_helper.rb`)
```ruby
# Count total items in cart
def cart_items_count
  return 0 if session[:cart].nil? || session[:cart].empty?
  session[:cart].sum { |item| item["quantity"].to_i }
end

# Check if cart has items
def cart_has_items?
  !session[:cart].nil? && !session[:cart].empty?
end

# Determine if panel should be shown (with path exclusions)
def should_show_cart_panel?
  return false unless cart_has_items?
  
  current_path = request.path_info
  excluded_paths = [
    '/cart', '/cart/', '/cart/show', '/cart/index',
    '/cart/checkout', '/cart/precheckout', '/cart/payment',
    '/cart/payments', '/cart/thanks'
  ]
  
  return false if excluded_paths.any? { |path| current_path.start_with?(path) }
  true
end
```

### 2. Main Panel (`app/views/layouts/parts/_final_mobile_cart_panel.haml`)

#### Structure
- **Badge**: Red circle with item count
- **Button**: Orange "Перейти в корзину" button (#ef845b)
- **Price**: Total price with ₽ symbol
- **Filler**: iPhone-specific bottom area fill

#### CSS Features
- Fixed positioning at bottom with proper z-index (9999)
- Safe area insets for iPhone X+ models
- Responsive breakpoints (<1024px show, ≥1024px hide)
- Smooth transitions and hover effects

#### JavaScript Features
- AJAX updates via `/cart/stat` endpoint
- Cache-busting headers and timestamps
- Real-time visibility control
- iPhone detection and filler management
- Event listeners for cart modifications

### 3. Backend Endpoint (`app/controllers/cart.rb`)
```ruby
get :stat do
  # Prevent caching
  response['Cache-Control'] = 'no-cache, no-store, must-revalidate'
  response['Pragma'] = 'no-cache'
  response['Expires'] = '0'
  
  total_q = 0
  unless session[:cart].nil?
    session[:cart].each do |item|
      total_q += item["quantity"].to_i
    end
  end
  
  content_type :json
  { :total_s => total, :total_q => total_q }.to_json
end
```

### 4. Layout Integration
Panel integrated into all layouts:
- `app/views/layouts/application.haml`
- `app/views/layouts/catalog.haml`
- `app/views/layouts/+/applicationpr.haml`
- `app/views/layouts/+/catalogpr.haml`
- `app/views/layouts/erbhf.erb`

## iPhone-Specific Improvements

### Problem
iOS devices can show empty space below fixed bottom elements due to:
1. Dynamic viewport height changes (address bar hiding/showing)
2. Safe area handling differences
3. Viewport meta tag interpretations

### Solution
1. **Safe Area Insets**: Using `env(safe-area-inset-bottom, 0)` for proper spacing
2. **Filler Block**: Additional element to fill potential empty space
3. **iOS Detection**: JavaScript detects iOS devices to show filler only when needed
4. **Dynamic Height**: Panel min-height adapts to safe area requirements

### CSS Implementation
```css
.mobile-cart-panel {
  min-height: calc(76px + env(safe-area-inset-bottom, 0));
  padding-bottom: env(safe-area-inset-bottom, 0);
}

.mobile-cart-panel-filler {
  position: fixed;
  bottom: calc(-1 * env(safe-area-inset-bottom, 0) - 50px);
  height: calc(50px + env(safe-area-inset-bottom, 0));
  background-color: #fff;
  display: none; /* Shown only on iOS when panel is visible */
}
```

### JavaScript Control
```javascript
// Show filler only on iOS devices when panel is visible
if (cartFiller && /iPad|iPhone|iPod/.test(navigator.userAgent)) {
  cartFiller.style.display = 'block';
}
```

## Compatibility Notes
- **ActiveRecord**: Uses 3.x syntax (`where().first` instead of `find_by`)
- **Encoding**: UTF-8 with ₽ symbol support (emoji avoided due to encoding issues)
- **Cache Prevention**: Multiple techniques to prevent stale cart data
- **Multi-layout**: Works across different layout templates

## Debug Features
- Console logging for troubleshooting
- Visual debug information in browser console
- State tracking for panel visibility decisions

## Testing
1. **Add items to cart**: Panel should appear
2. **Remove all items**: Panel should disappear
3. **Navigate to /cart**: Panel should hide
4. **Resize window**: Panel responds to breakpoints
5. **iPhone testing**: Check for empty space below panel

## Updates Made

### Latest Improvements (Current Session)
1. **Enhanced iPhone Fix**:
   - Improved filler positioning using bottom-based layout
   - Better safe area inset handling
   - iOS-specific detection and control
   - Synchronized filler visibility with main panel

2. **CSS Refinements**:
   - More accurate min-height calculations
   - Better z-index management
   - Improved responsive behavior

3. **JavaScript Enhancements**:
   - Added filler element control
   - iOS device detection
   - Synchronized show/hide logic
   - Better error handling

The mobile cart panel is now fully functional with enhanced iPhone compatibility to prevent empty area visibility issues.

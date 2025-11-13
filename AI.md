# AI Instructions

Hello AI! 👋

Please, do not modify this file!

This repository is a eCommerce web application built with Ruby (Padrino framework).

## Codebase analysis

Here's a brief project structure I reviewed:

### 🎯 **Project Type**
**Online Flower Shop** in Ruby (Padrino framework) with multi-region support

### 🏗 **Architecture**
- **Framework**: Padrino (built on Sinatra)
- **ORM**: ActiveRecord 3.x
- **DB**: MySQL
- **Cache**: Redis
- **Templates**: HAML
- **Background Jobs**: Sidekiq
- **Web Server**: Passenger/Puma

### 📁 **Directory Structure**
```
/app/ - Main application
/controllers/ - Controllers (including API v1)
/models/ - Data models (48 models)
/views/ - HAML templates
/admin/ - Admin Panel
/config/ - Configuration
/lib/ - Libraries and File Uploaders
/workers/ - Sidekiq Workers
```

### 🗃 **Main Models**
- **Product** - Products with sets (standard/small/luxury)
- **Category** - Hierarchical categories
- **Order/Order_product** - Orders and products within orders
- **Subdomain** - Subdomains for cities
- **UserAccount** - Users
- **ProductComplect** - Product-set relationship with prices

### 🌍 **Multi-Regional**
- Subdomain system for different cities
- Regional prices and discounts
- Separate delivery settings

### 🔧 **Features**
- Complex pricing system with regional coefficients
- Integration with external APIs (1C, payments)
- System Promotions and discounts
- Redis for sessions and caching
- API endpoints for mobile apps

### ⚠️ **Considered limitations**
- ✅ No database structure changes without approval
- ✅ No frontend resources (JS/CSS/images)
- ✅ No migration creation

## Rules

- Use Russian to communicate in the chat.
- Use English for comments in code.
- Use the `./docs` directory for documentation.
- Use the `./tmp` directory for temporary files and one-time scripts.
- We currently do not support Windows or macOS. Only Ubuntu in the latest LTS version.

## Style

- Use two spaces for indentation.
- Use one space to indent code before an inline comment.

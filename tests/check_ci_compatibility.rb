#!/usr/bin/env ruby
# encoding: utf-8

# Проверка совместимости с CI окружением

puts "🔍 Проверка CI совместимости..."

begin
  require 'multi_captcha'
  puts "❌ multi_captcha доступен (локальное окружение)"
rescue LoadError
  puts "✅ multi_captcha НЕ доступен (как в CI)"
end

puts "📋 Загрузка test_setup..."
require_relative 'test_setup'

begin
  puts "🧪 Тест mock функциональности..."
  result = MultiCaptcha.verify({})
  puts "✅ MultiCaptcha mock работает: #{result}"
rescue => e
  puts "❌ Ошибка mock: #{e.message}"
  exit 1
end

puts "🎯 Запуск простого unit теста..."
begin
  require 'minitest/autorun'
  require 'json'
  puts "✅ Minitest и JSON загружены"
rescue => e
  puts "❌ Ошибка загрузки зависимостей: #{e.message}"
  exit 1
end

puts "🎉 CI совместимость проверена успешно!"

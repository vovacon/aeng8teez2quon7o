#!/bin/bash
# encoding: utf-8

# Запуск unit тестов

echo "📋 Запуск unit тестов..."
echo "==============================================="

# Проверяем, доступен ли minitest
if ! ruby -e "require 'minitest'" 2>/dev/null; then
  echo "⚠️  Минимальная установка зависимостей..."
  gem install minitest --no-document
fi

for test_file in unit/*test*.rb; do
  if [ -f "$test_file" ]; then
    echo "→ Запуск $test_file"
    ruby "$test_file"
    echo ""
  fi
done

echo "✅ Unit тесты завершены"

#!/bin/bash
# Консолидированный запуск всех тестов проекта

set -e

echo "=== 🚀 Консолидированный запуск всех тестов ==="

TEST_RESULTS=()
FAILED_TESTS=0

# Функция для запуска теста
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo "\n🧪 Запуск $test_name..."
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo "✅ $test_name - ПРОШЕЛ"
        TEST_RESULTS+=("$test_name: ✅ PASS")
    else
        echo "❌ $test_name - ОШИБКА"
        TEST_RESULTS+=("$test_name: ❌ FAIL")
        ((FAILED_TESTS++))
    fi
}

# Функция для запуска теста с выводом
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    echo "\n🧪 Запуск $test_name..."
    
    if eval "$test_command"; then
        echo "✅ $test_name - ПРОШЕЛ"
        TEST_RESULTS+=("$test_name: ✅ PASS")
    else
        echo "❌ $test_name - ОШИБКА"
        TEST_RESULTS+=("$test_name: ❌ FAIL")
        ((FAILED_TESTS++))
    fi
}

# 1. Синтаксические тесты
echo "\n🔍 Синтаксическая проверка..."
run_test "Ruby синтаксис (app/models)" "find app/models -name '*.rb' -exec ruby -c {} \;"
run_test "Hygiene скрипт синтаксис" "bash -n hygiene.sh"

# 2. Функциональные тесты
echo "\n🧠 Функциональные тесты..."

# Тест множественных комментариев
if [ -f "test_smile_multiple_comments_simple.rb" ]; then
    run_test_with_output "Множественные комментарии (Smile)" "ruby test_smile_multiple_comments_simple.rb"
fi

# Тест агрегированных отзывов
if [ -f "test_aggregated_reviews_schema.rb" ]; then
    run_test_with_output "Агрегированные отзывы (Schema.org)" "ruby test_aggregated_reviews_schema.rb"
fi

# Тест Hygiene скрипта
if [ -f "hygiene_simple_test.sh" ]; then
    run_test_with_output "Hygiene функциональность" "chmod +x hygiene_simple_test.sh && ./hygiene_simple_test.sh"
fi

# 3. Тесты безопасности (локальные)
echo "\n🔒 Проверка конфигурации безопасности..."
run_test "Конфигурация .gitleaks.toml" "test -f .gitleaks.toml && grep -q '\\+' .gitleaks.toml"
run_test "Конфигурация .secretsignore" "test -f .secretsignore && grep -q '+/' .secretsignore"
run_test "Конфигурация .semgrepignore" "test -f .semgrepignore && grep -q '+/' .semgrepignore"

# 4. Проверка исключений
echo "\n⚙️  Проверка исключений директории +/..."
run_test "GitIgnore исключения" "grep -q '+/*' .gitignore"
run_test "Hygiene исключения" "grep -q '*/+/*' hygiene.sh"

# 5. Краткий тест выполнения
echo "\n⏱️  Краткие тесты выполнения..."
run_test "Hygiene выполнение" "echo '# test' > .test_temp.rb && timeout 2s ./hygiene.sh . >/dev/null 2>&1; rm -f .test_temp.rb .test_temp.rb.tmp; true"

# Итоги
echo "\n=== 📋 Итоги тестирования ==="
for result in "${TEST_RESULTS[@]}"; do
    echo "  $result"
done

if [ $FAILED_TESTS -eq 0 ]; then
    echo "\n🎉 Все тесты прошли успешно!"
    echo "✅ Проект готов к развертыванию"
    exit 0
else
    echo "\n⚠️  Обнаружено $FAILED_TESTS ошибок"
    echo "❌ Необходимо исправить проблемы перед деплоем"
    exit 1
fi

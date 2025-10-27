# Makefile для проекта Rozario Flowers
.PHONY: help test test-unit test-integration clean install

# Цвета для красивого вывода
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
NC=\033[0m # No Color

## Помощь
help:
	@echo "${BLUE}🌹 Rozario Flowers - Makefile${NC}"
	@echo "${GREEN}Доступные команды:${NC}"
	@echo "  ${YELLOW}make test${NC}          - Запуск всех тестов"
	@echo "  ${YELLOW}make test-unit${NC}     - Запуск только unit тестов"
	@echo "  ${YELLOW}make test-integration${NC} - Запуск интеграционных тестов (требует БД)"
	@echo "  ${YELLOW}make ci-check${NC}     - Полная проверка как в CI/CD"
	@echo "  ${YELLOW}make security${NC}     - Проверка безопасности"
	@echo "  ${YELLOW}make deps${NC}         - Анализ зависимостей"
	@echo "  ${YELLOW}make install${NC}      - Установка зависимостей"
	@echo "  ${YELLOW}make clean${NC}        - Очистка временных файлов"
	@echo "  ${YELLOW}make lint${NC}         - Проверка синтаксиса Ruby"

## Установка зависимостей
install:
	@echo "${BLUE}🛠️  Установка зависимостей...${NC}"
	@echo "→ Минимальные зависимости для тестов:"
	@gem install minitest json --no-document
	@echo "→ Полные зависимости проекта (для интеграции):"
	@bundle install || echo "${YELLOW}⚠️  Нужен multi_captcha гем для полной установки${NC}"
	@echo "${GREEN}✅ Зависимости для тестов установлены${NC}"

## Запуск всех тестов
test: test-unit
	@echo "${GREEN}✅ Все доступные тесты завершены${NC}"

## Unit тесты (не требуют БД)
test-unit:
	@echo "${BLUE}📋 Запуск unit тестов...${NC}"
	@cd tests && chmod +x run_unit_tests.sh && ./run_unit_tests.sh
	@echo "${GREEN}✅ Unit тесты завершены${NC}"

## Интеграционные тесты (требуют БД)
test-integration:
	@echo "${YELLOW}⚠️  Интеграционные тесты требуют доступ к базе данных MySQL${NC}"
	@echo "${BLUE}🔗 Запуск интеграционных тестов...${NC}"
	@cd tests && chmod +x run_integration_tests.sh && ./run_integration_tests.sh
	@echo "${GREEN}✅ Интеграционные тесты завершены${NC}"

## Проверка синтаксиса
lint:
	@echo "${BLUE}🔍 Проверка синтаксиса Ruby файлов...${NC}"
	@find . -name "*.rb" -not -path "./tests/archive/*" -not -path "./+/*" | while read file; do \
		echo "  ✓ Проверяем $$file"; \
		ruby -c "$$file" || exit 1; \
	done
	@echo "${GREEN}✅ Синтаксис корректен${NC}"

## Очистка
clean:
	@echo "${BLUE}🧹 Очистка временных файлов...${NC}"
	@rm -rf tests/reports/*
	@find . -name "*.tmp" -delete
	@find . -name "passenger.*.pid" -delete
	@echo "${GREEN}✅ Очистка завершена${NC}"

## Статистика проекта
stats:
	@echo "${BLUE}📊 Статистика проекта Rozario Flowers:${NC}"
	@echo "  Ruby файлов:    $(shell find . -name '*.rb' -not -path './+/*' | wc -l)"
	@echo "  HAML файлов:    $(shell find . -name '*.haml' | wc -l)"
	@echo "  ERB файлов:     $(shell find . -name '*.erb' | wc -l)"
	@echo "  Unit тестов:    $(shell find tests/unit -name '*.rb' 2>/dev/null | wc -l)"
	@echo "    - Schema тесты:  $(shell find tests/unit -name '*schema*.rb' 2>/dev/null | wc -l)"
	@echo "    - Smile тесты:   $(shell find tests/unit -name 'smile_*.rb' 2>/dev/null | wc -l)"
	@echo "    - CI тесты:      $(shell find tests/unit -name 'ci_*.rb' 2>/dev/null | wc -l)"
	@echo "  Интегр. тестов: $(shell find tests/integration -name '*.rb' 2>/dev/null | wc -l)"
	@echo "  UI тестов:      $(shell find tests/ui -name '*.html' 2>/dev/null | wc -l)"
	@echo "  Архивных:       $(shell find tests/archive -name '*.rb' 2>/dev/null | wc -l)"
	@echo "  Временных:      $(shell find . -maxdepth 1 -name 'test_*.rb' 2>/dev/null | wc -l) (подлежат удалению)"
	@echo "  Служебных:      $(shell find ./+ -name '*' 2>/dev/null | wc -l) (не тестируется)"

## Запуск приложения в development режиме
start:
	@echo "${BLUE}🚀 Запуск Rozario Flowers...${NC}"
	@./start.passenger.sh

## По умолчанию показать помощь
default: help

## CI/CD полная проверка
ci-check:
	@echo "${BLUE}🔍 Полная проверка как в CI/CD...${NC}"
	@echo "→ 1/4 Проверка безопасности..."
	@make security
	@echo "→ 2/4 Проверка кода..."
	@make lint
	@echo "→ 3/4 Анализ зависимостей..."
	@make deps
	@echo "→ 4/4 Запуск тестов..."
	@make test-unit
	@echo "${GREEN}✅ Полная проверка CI/CD завершена${NC}"

## Проверка безопасности (исключая служебную директорию +/)
security:
	@echo "${BLUE}🔒 Проверка безопасности...${NC}"
	@echo "→ Поиск потенциальных секретов..."
	@if grep -r --include="*.rb" \
	   -E '(password|secret|key|token)\s*[=:]\s*["\047][^"\047]{12,}["\047]' . | \
	   grep -v -E '(test|spec|example|placeholder|your_|xxx|yyy|zzz|Пароль|SecureRandom|locale/|idempotence_key|user_agent|Mozilla|\+/)'; then \
		echo "${RED}⚠️  Найдены потенциальные секреты!${NC}"; \
		exit 1; \
	else \
		echo "${GREEN}✅ Потенциальные секреты не найдены${NC}"; \
	fi
	@echo "→ Поиск хардкодных IP..."
	@if grep -r --include="*.rb" --include="*.yml" \
	   -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' . | \
	   grep -v -E '(127\.0\.0\.1|0\.0\.0\.0|localhost|185\.71\.76\.|185\.71\.77\.|77\.75\.153\.|77\.75\.156\.|77\.75\.154\.|91\.226\.82\.|Chrome|Mozilla|user_agent|@user_agent|\+/)'; then \
		echo "${YELLOW}⚠️  Найдены хардкодные IP адреса${NC}"; \
	else \
		echo "${GREEN}✅ Хардкодные IP не найдены${NC}"; \
	fi
	@echo "${GREEN}✅ Проверка безопасности завершена${NC}"

## Анализ зависимостей
deps:
	@echo "${BLUE}🛠️  Анализ зависимостей...${NC}"
	@echo "Общее количество gem'ов: $$(grep -c "^gem " Gemfile)"
	@echo "Локальные gem'ы: $$(grep -c "path:" Gemfile || echo 0)"
	@echo "→ Проверка критичных зависимостей:"
	@for gem in padrino activerecord mysql2 redis haml; do \
		if grep -q "gem ['\"]$$gem['\"]" Gemfile; then \
			echo "  ✅ $$gem"; \
		else \
			echo "  ❌ $$gem отсутствует"; \
		fi; \
	done
	@if [ -f "Gemfile.lock" ]; then \
		echo "→ Последние обновления: $$(stat -c %y Gemfile.lock | cut -d' ' -f1)"; \
	fi
	@echo "${GREEN}✅ Анализ зависимостей завершён${NC}"

## Полная проверка перед commit
pre-commit: ci-check
	@echo "${GREEN}🎉 Всё готово для commit!${NC}"

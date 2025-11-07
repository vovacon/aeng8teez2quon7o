# encoding: utf-8
#!/usr/bin/env ruby
# encoding: utf-8

# Тест для проверки CI/CD интеграции
require 'minitest/autorun'
require 'yaml'
require 'json'

class CiIntegrationTest < Minitest::Test
  
  def setup
    @project_root = File.expand_path('../..', __dir__)
    @ci_config_path = File.join(@project_root, '.github', 'workflows', 'tests.yml')
    @test_scripts = [
      File.join(@project_root, 'test_smile_logic.rb'),
      File.join(@project_root, 'test_smile_fix_verification.rb')
    ]
  end
  
  def test_ci_config_exists
    assert File.exist?(@ci_config_path), "CI конфигурация должна существовать"
  end
  
  def test_ci_includes_unit_tests
    ci_config = File.read(@ci_config_path)
    
    assert ci_config.include?('unit-tests'), "CI должен содержать job unit-tests"
    assert ci_config.include?('./run_unit_tests.sh'), "CI должен запускать unit тесты"
  end
  
  def test_ci_includes_smile_tests
    ci_config = File.read(@ci_config_path)
    
    assert ci_config.include?('test_smile_fix_verification.rb'), "CI должен включать тест SQL-запросов Smile"
    assert ci_config.include?('test_smile_logic.rb'), "CI должен включать основной тест Smile"
  end
  
  def test_smile_test_scripts_exist
    @test_scripts.each do |script|
      assert File.exist?(script), "Тестовый скрипт должен существовать: #{script}"
      assert File.executable?(script), "Тестовый скрипт должен быть исполняемым: #{script}"
    end
  end
  
  def test_ci_reports_correct_test_count
    ci_config = File.read(@ci_config_path, encoding: 'UTF-8')
    
    # Проверяем, что в CI указано правильное количество тестов
    assert ci_config.include?('100+ тестов'.force_encoding('UTF-8')), 
      "CI должен отображать актуальное количество тестов: 100+"
    
    assert ci_config.include?('Smile Products'), "CI должен упоминать тесты Smile Products"
  end
  
  def test_ci_triggers_on_correct_branches
    ci_config = File.read(@ci_config_path)
    
    # Проверяем, что CI запускается на sketch-wip
    assert ci_config.include?('sketch-wip'), "CI должен запускаться на sketch-wip ветке"
    assert ci_config.include?('main'), "CI должен запускаться на main ветке"
  end
  
  def test_ci_includes_smile_specific_paths
    ci_config = File.read(@ci_config_path)
    
    # Проверяем, что CI реагирует на изменения в ключевых папках
    assert ci_config.include?('app/**'), "CI должен реагировать на изменения в app/"
    assert ci_config.include?('admin/**'), "CI должен реагировать на изменения в admin/"
    assert ci_config.include?('tests/**'), "CI должен реагировать на изменения в tests/"
  end
  
  def test_unit_test_runner_script_exists
    script_path = File.join(@project_root, 'tests', 'run_unit_tests.sh')
    assert File.exist?(script_path), "Скрипт запуска unit тестов должен существовать"
    assert File.executable?(script_path), "Скрипт должен быть исполняемым"
    
    # Проверяем, что скрипт автоматически находит все unit тесты
    script_content = File.read(script_path)
    assert script_content.include?('unit/*test*.rb'), 
      "Скрипт должен автоматически находить все unit тесты"
  end
  
  def test_ci_has_proper_error_handling
    ci_config = File.read(@ci_config_path)
    
    # Проверяем, что CI имеет обработку ошибок
    assert ci_config.include?('if: always()'), "CI должен содержать обработку ошибок"
    assert ci_config.include?('needs:'), "CI должен содержать зависимости между jobs"
  end
  
  def test_ci_artifact_upload
    ci_config = File.read(@ci_config_path)
    
    # Проверяем, что CI сохраняет результаты тестов
    assert ci_config.include?('upload-artifact'), "CI должен сохранять artifacts"
    assert ci_config.include?('test-results'), "CI должен сохранять результаты тестов"
  end
end

if __FILE__ == $0
  puts "Running CI/CD integration tests..."
end
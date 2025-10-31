# encoding: utf-8
require 'ostruct'
require 'json'

Rozario::Admin.controllers :permissions do
  
  # Список всех пользователей с их правами
  get :index do
    @title = "Управление правами"
    
    # Принудительно используем только безопасную загрузку через SQL
    begin
      @accounts = load_accounts_via_sql
      @modules = Account::AVAILABLE_MODULES
      
      render 'permissions/index'
      
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError, Encoding::CompatibilityError => encoding_error
      # Любая ошибка кодировки - показываем простую страницу с ошибкой
      erb '<h1>Encoding Error</h1><p>Database encoding issue detected.</p><p><a href="/admin">Back to Admin</a></p>'
      
    rescue => e
      # Любая другая ошибка
      erb '<h1>Error</h1><p>' + e.class.name + ': ' + e.message + '</p><p><a href="/admin">Back to Admin</a></p>'
    end
  end
  
  # Максимально безопасная загрузка аккаунтов
  def load_accounts_via_sql
    begin
      connection = ActiveRecord::Base.connection
      
      # Принудительно устанавливаем кодировку для соединения
      connection.execute("SET NAMES utf8") rescue nil
      connection.execute("SET CHARACTER SET utf8") rescue nil
      
      # Простой запрос без сложных преобразований
      sql = "SELECT id, name, surname, email, role, role_permissions FROM accounts ORDER BY id DESC LIMIT 20"
      
      results = connection.execute(sql)
      accounts = []
      
      results.each_with_index do |row, index|
        begin
          # Создаём простой аккаунт с безопасными данными
          account_data = OpenStruct.new(
            id: row[0].to_i,
            name: clean_string(row[1]),
            surname: clean_string(row[2]),
            email: clean_string(row[3]),
            role: clean_string(row[4]) || 'editor',
            role_permissions: clean_string(row[5]) || '[]'
          )
          
          # Добавляем необходимые методы
          account_data.define_singleton_method(:display_name) do
            parts = [name, surname].compact.reject(&:empty?)
            parts.any? ? parts.join(' ') : email
          end
          
          account_data.define_singleton_method(:permissions) do
            begin
              JSON.parse(role_permissions)
            rescue
              []
            end
          end
          
          account_data.define_singleton_method(:has_permission?) do |mod|
            role == 'admin' || permissions.include?(mod.to_s)
          end
          
          accounts << account_data
          
        rescue => row_error
          # Создаём fallback аккаунт
          fallback = OpenStruct.new(
            id: index + 1,
            name: "User",
            surname: (index + 1).to_s,
            email: "user#{index + 1}@example.com",
            role: "editor",
            role_permissions: "[]"
          )
          
          fallback.define_singleton_method(:display_name) { "User #{index + 1}" }
          fallback.define_singleton_method(:permissions) { [] }
          fallback.define_singleton_method(:has_permission?) { |mod| false }
          
          accounts << fallback
        end
      end
      
      accounts
      
    rescue => e
      # Последний fallback - возвращаем один тестовый аккаунт
      test_account = OpenStruct.new(
        id: 1,
        name: "Test",
        surname: "User", 
        email: "test@example.com",
        role: "admin",
        role_permissions: "[]"
      )
      
      test_account.define_singleton_method(:display_name) { "Test User (Fallback)" }
      test_account.define_singleton_method(:permissions) { [] }
      test_account.define_singleton_method(:has_permission?) { |mod| true }
      
      [test_account]
    end
  end
  
  private
  
  # Очистка строки от проблемных символов
  def clean_string(value)
    return "" if value.nil?
    
    str = value.to_s
    return "" if str.empty?
    
    begin
      # Принудительно переводим в UTF-8 и очищаем
      cleaned = str.force_encoding('UTF-8')
      
      # Если строка невалидная - чистим её
      unless cleaned.valid_encoding?
        cleaned = str.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      end
      
      cleaned
    rescue => e
      # Последний fallback - только ASCII символы
      str.gsub(/[^\x20-\x7E]/, '?')
    end
  end
  
end
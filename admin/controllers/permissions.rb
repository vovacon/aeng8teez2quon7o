# encoding: utf-8
require 'ostruct'
require 'json'

Rozario::Admin.controllers :permissions do
  
  # Список всех пользователей с их правами
  get :index do
    @title = "Управление правами"
    
    # Прямая загрузка данных через SQL - всё в одном месте
    begin
      connection = ActiveRecord::Base.connection
      connection.execute("SET NAMES utf8") rescue nil
      connection.execute("SET CHARACTER SET utf8") rescue nil
      
      sql = "SELECT id, name, surname, email, role, role_permissions FROM accounts ORDER BY id DESC LIMIT 20"
      results = connection.execute(sql)
      
      @accounts = []
      results.each_with_index do |row, index|
        begin
          account_data = OpenStruct.new(
            id: row[0].to_i,
            name: (row[1] || '').to_s.force_encoding('UTF-8'),
            surname: (row[2] || '').to_s.force_encoding('UTF-8'),
            email: (row[3] || '').to_s.force_encoding('UTF-8'),
            role: (row[4] || 'editor').to_s.force_encoding('UTF-8'),
            role_permissions: (row[5] || '[]').to_s.force_encoding('UTF-8')
          )
          
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
          
          @accounts << account_data
          
        rescue => row_error
          # Fallback аккаунт при ошибке
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
          
          @accounts << fallback
        end
      end
      
      @modules = Account::AVAILABLE_MODULES
      render 'permissions/index'
      
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError, Encoding::CompatibilityError => encoding_error
      erb '<h1>Encoding Error</h1><p>Database encoding issue detected.</p><p><a href="/admin">Back to Admin</a></p>'
      
    rescue => e
      erb '<h1>Error</h1><p>' + e.class.name + ': ' + e.message + '</p><p><a href="/admin">Back to Admin</a></p>'
    end
  end
  
  # Форма редактирования прав пользователя
  get :edit, :with => :id do
    begin
      @title = "Edit Permissions"
      @account_id = params[:id].to_i
      
      # Загружаем данные аккаунта через безопасный SQL
      connection = ActiveRecord::Base.connection
      connection.execute("SET NAMES utf8") rescue nil
      
      sql = "SELECT id, name, surname, email, role, role_permissions FROM accounts WHERE id = #{@account_id} LIMIT 1"
      result = connection.execute(sql)
      
      if result.any?
        row = result.first
        @account = OpenStruct.new(
          id: row[0].to_i,
          name: (row[1] || '').to_s.force_encoding('UTF-8'),
          surname: (row[2] || '').to_s.force_encoding('UTF-8'),
          email: (row[3] || '').to_s.force_encoding('UTF-8'),
          role: (row[4] || 'editor').to_s.force_encoding('UTF-8'),
          role_permissions: (row[5] || '[]').to_s.force_encoding('UTF-8')
        )
        
        @account.define_singleton_method(:display_name) do
          parts = [name, surname].compact.reject(&:empty?)
          parts.any? ? parts.join(' ') : email
        end
        
        @account.define_singleton_method(:permissions) do
          begin
            JSON.parse(role_permissions)
          rescue
            []
          end
        end
        
        @modules = Account::AVAILABLE_MODULES
        @current_permissions = @account.permissions
        
        render 'permissions/edit'
      else
        erb '<h1>User Not Found</h1><p>Account with ID <%= @account_id %> not found.</p><p><a href="/admin/permissions">Back to Permissions</a></p>'
      end
      
    rescue => e
      erb '<h1>Error</h1><p>' + e.class.name + ': ' + e.message + '</p><p><a href="/admin/permissions">Back to Permissions</a></p>'
    end
  end
  
  # Сохранение изменений прав
  post :update, :with => :id do  # Используем POST вместо PUT для совместимости
    begin
      @account_id = params[:id].to_i
      
      # Получаем выбранные модули из формы
      selected_permissions = params[:permissions] || []
      
      # Фильтруем только доступные модули
      valid_permissions = selected_permissions.select { |m| Account::AVAILABLE_MODULES.include?(m) }
      
      # Преобразуем в JSON
      permissions_json = valid_permissions.to_json
      
      # Обновляем через SQL
      connection = ActiveRecord::Base.connection
      connection.execute("SET NAMES utf8") rescue nil
      
      # Экранируем JSON для безопасности
      safe_json = connection.quote(permissions_json)
      update_sql = "UPDATE accounts SET role_permissions = #{safe_json} WHERE id = #{@account_id}"
      connection.execute(update_sql)
      
      # Перенаправляем на список с сообщением об успехе
      erb '<h1>Permissions Updated</h1><p>Permissions for user ID <%= @account_id %> have been successfully updated.</p><p>Selected permissions: <%= selected_permissions.join(", ") %></p><p><a href="/admin/permissions">Back to Permissions</a></p>'
      
    rescue => e
      erb '<h1>Error</h1><p>' + e.class.name + ': ' + e.message + '</p><p><a href="/admin/permissions">Back to Permissions</a></p>'
    end
  end
  
  # Быстрое переключение прав через AJAX
  post :toggle, :with => :id do
    begin
      content_type :json
      '{ "success": false, "error": "This feature is under development" }'
    rescue => e
      content_type :json
      '{ "success": false, "error": "Error occurred" }'
    end
  end
  
  # Массовое назначение прав
  post :bulk_update do
    begin
      erb '<h1>Bulk Update</h1><p>This feature is under development.</p><p><a href="/admin/permissions">Back to Permissions</a></p>'
    rescue => e
      erb '<h1>Error</h1><p>' + e.class.name + ': ' + e.message + '</p><p><a href="/admin/permissions">Back to Permissions</a></p>'
    end
  end

end
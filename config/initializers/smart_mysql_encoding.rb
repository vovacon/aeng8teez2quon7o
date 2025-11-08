# encoding: utf-8
# Умная настройка MySQL кодировки без патчинга String
# ВАЖНО: Инициализируется только после установления соединения с БД

if defined?(ActiveRecord)
  # Настройка кодировки при соединении с MySQL
  module SmartMysqlEncoding
    def self.setup_connection(connection)
      return unless connection.class.name.include?('Mysql')
      
      begin
        # Пробуем utf8mb4 (поддерживает emoji и другие 4-байтовые символы)
        connection.execute("SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci")
        connection.execute("SET CHARACTER SET utf8mb4")
      rescue => e
        begin
          # Fallback на обычный utf8
          connection.execute("SET NAMES utf8 COLLATE utf8_unicode_ci")
          connection.execute("SET CHARACTER SET utf8")
        rescue => inner_e
          # Если и это не сработало - просто продолжаем
          # Лучше работать с дефолтными настройками, чем сломать приложение
        end
      end
    end
    
    def self.apply_to_existing_connection
      # Проверяем, что соединение уже установлено
      if ActiveRecord::Base.connected?
        ActiveRecord::Base.connection_pool.with_connection do |conn|
          setup_connection(conn)
        end
      end
    end
    
    def self.patch_new_connections
      # Настраиваем кодировку для новых соединений
      return unless ActiveRecord::Base.connected?
      
      ActiveRecord::Base.connection_pool.instance_eval do
        # Проверяем, что метод еще не переопределен
        unless instance_methods.include?(:original_new_connection)
          alias_method :original_new_connection, :new_connection
          
          def new_connection
            conn = original_new_connection
            SmartMysqlEncoding.setup_connection(conn)
            conn
          end
        end
      end
    end
  end
  
  # Используем отложенную инициализацию после загрузки приложения
  # Это будет выполнено в config/apps.rb или после Padrino.load!
  if defined?(Padrino) && Padrino.respond_to?(:after_load)
    Padrino.after_load do
      SmartMysqlEncoding.apply_to_existing_connection
      SmartMysqlEncoding.patch_new_connections
    end
  else
    # Fallback для случая, если after_load недоступен
    # Выполняем при первом обращении к модели
    ActiveRecord::Base.class_eval do
      def self.inherited(subclass)
        super
        # При первом создании модели пытаемся настроить кодировку
        SmartMysqlEncoding.apply_to_existing_connection
        SmartMysqlEncoding.patch_new_connections
        
        # Убираем этот callback после первого выполнения
        class << self
          remove_method :inherited if method_defined?(:inherited)
        end
      end
    end
  end
end
# Дополнительная безопасность: если ничего не сработало,
# попробуем настроить при первом SQL запросе
if defined?(ActiveRecord)
  original_execute_method = nil
  
  ActiveRecord::Base.connection_pool.instance_eval do
    def with_connection
      super do |conn|
        # При первом использовании соединения настраиваем кодировку
        unless @smart_encoding_applied
          SmartMysqlEncoding.setup_connection(conn)
          @smart_encoding_applied = true
        end
        yield conn
      end
    end
  end if ActiveRecord::Base.connected? rescue false
end
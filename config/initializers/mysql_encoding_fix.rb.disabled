# encoding: utf-8
# Специальный фикс для MySQL и кодировки

if defined?(ActiveRecord)
  # Патч для MySQL2 adapter для принудительной установки кодировки
  module EncodingFix
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      def connection
        conn = original_connection
        # Принудительно устанавливаем UTF-8 для MySQL
        if conn.class.name.include?('Mysql')
          begin
            conn.execute("SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci")
            conn.execute("SET CHARACTER SET utf8mb4")
          rescue => e
            # Если utf8mb4 не поддерживается - пробуем обычный utf8
            begin
              conn.execute("SET NAMES utf8 COLLATE utf8_unicode_ci")
              conn.execute("SET CHARACTER SET utf8")
            rescue => inner_e
              # Ничего не можем сделать - просто продолжаем
            end
          end
        end
        conn
      end
      
      alias_method :original_connection, :connection
    end
  end
  
  # Применяем патч к ActiveRecord::Base
  ActiveRecord::Base.class_eval do
    include EncodingFix
  end
  
  # Дополнительно патчим метод to_s для String
  class String
    alias_method :original_to_s, :to_s unless method_defined?(:original_to_s)
    
    def to_s
      result = original_to_s
      
      # Если строка не в UTF-8 - пытаемся исправить
      if result.respond_to?(:encoding) && result.encoding != Encoding::UTF_8
        begin
          result.force_encoding('UTF-8')
        rescue => e
          # Если не получилось - оставляем как есть
          result
        end
      else
        result
      end
    end
  end
  
end
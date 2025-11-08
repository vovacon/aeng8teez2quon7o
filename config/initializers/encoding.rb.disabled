# encoding: utf-8
# Конфигурация кодировки для избежания Encoding::UndefinedConversionError

# Устанавливаем UTF-8 как стандартную кодировку
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Конфигурация MySQL для правильной работы с UTF-8
if defined?(ActiveRecord)
  # Подключаем обработчик после установки соединения
  ActiveRecord::Base.class_eval do
    after_initialize :ensure_utf8_encoding
    
    private
    
    def ensure_utf8_encoding
      # Проходим по всем строковым атрибутам
      self.class.columns.each do |column|
        if column.type == :string || column.type == :text
          value = read_attribute(column.name)
          if value && value.respond_to?(:force_encoding)
            begin
              # Если строка не в UTF-8, пытаемся преобразовать
              unless value.encoding == Encoding::UTF_8 && value.valid_encoding?
                # Пробуем Windows-1251 -> UTF-8 (частая кодировка для русского)
                converted = value.dup.force_encoding('Windows-1251').encode('UTF-8', 
                  invalid: :replace, undef: :replace, replace: '?')
                write_attribute(column.name, converted)
              end
            rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError => e
              # Если преобразование неудачно, чистим строку
              cleaned = value.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
              write_attribute(column.name, cleaned)
            rescue => e
              # Любая другая ошибка - оставляем как есть
              # Можно логировать ошибку при необходимости
            end
          end
        end
      end
    end
  end
end

# Монки-патч для String, чтобы облегчить работу с кодировкой
class String
  def safe_utf8
    return self if encoding == Encoding::UTF_8 && valid_encoding?
    
    begin
      # Попытка преобразования из Windows-1251
      dup.force_encoding('Windows-1251').encode('UTF-8', 
        invalid: :replace, undef: :replace, replace: '?')
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      # Последняя попытка - принудительная очистка
      encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    end
  end
end
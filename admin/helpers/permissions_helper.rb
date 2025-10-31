# encoding: utf-8
module Rozario
  class Admin
    module PermissionsHelper
      
      # Преобразование названий модулей в человекочитаемый вид
      def humanize_module_name(module_name)
        begin
          translations = {
            'accounts' => 'Учетные записи',
            'products' => 'Товары',
            'categories' => 'Категории',
            'orders' => 'Заказы',
            'comments' => 'Комментарии',
            'news' => 'Новости',
            'articles' => 'Статьи',
            'pages' => 'Страницы',
            'clients' => 'Клиенты',
            'contacts' => 'Контакты',
            'seo' => 'SEO',
            'payment' => 'Платежи',
            'regions' => 'Регионы',
            'delivery' => 'Доставка',
            'discounts' => 'Скидки',
            'categorygroups' => 'Группы категорий',
            'complects' => 'Комплекты',
            'menus_on_main' => 'Меню на главной',
            'photos' => 'Фотографии',
            'albums' => 'Альбомы',
            'slides' => 'Слайды',
            'slideshows' => 'Слайд-шоу',
            'tags' => 'Теги',
            'disabled_dates' => 'Отключенные даты',
            'general_config' => 'Общая конфигурация',
            'smiles' => 'Отзывы (Смайлы)',
            'seo_texts' => 'SEO тексты'
          }
          
          result = translations[module_name.to_s] || module_name.to_s.humanize
          safe_encode_string(result)
        rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError => e
          # Fallback в случае проблем с кодировкой
          module_name.to_s
        end
      end
      
      # Безопасное преобразование строки в UTF-8
      def safe_encode_string(str)
        return str if str.nil? || str.empty?
        return str if str.encoding == Encoding::UTF_8 && str.valid_encoding?
        
        begin
          if str.respond_to?(:force_encoding)
            str.dup.force_encoding('UTF-8')
          else
            str.to_s
          end
        rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError => e
          str.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
        end
      end
      
      # Класс для отображения роли
      def role_class(role)
        case role.to_s
        when 'admin'
          'label-important'
        when 'manager' 
          'label-warning'
        when 'editor'
          'label-info'
        else
          'label-default'
        end
      end
      
      # Проверка прав для текущего пользователя
      def current_user_can_manage_permissions?
        return false unless current_account
        current_account.role == 'admin' || current_account.has_permission?('accounts')
      end
      
      # Безопасное отображение полей аккаунта
      def safe_display_account_field(field)
        return '' if field.nil? || field.empty?
        
        begin
          # Проверяем, что строка в правильной кодировке
          if field.encoding == Encoding::UTF_8 && field.valid_encoding?
            field
          else
            # Попытка принудительного преобразования
            field.dup.force_encoding('Windows-1251').encode('UTF-8', 
              invalid: :replace, undef: :replace, replace: '?')
          end
        rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError => e
          # Если все попытки неудачны
          field.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
        rescue => e
          # Любая другая ошибка - возвращаем безопасную строку
          "[Ошибка кодировки]"
        end
      end
      
    end
    
    helpers PermissionsHelper
  end
end

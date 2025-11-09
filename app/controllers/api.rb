# encoding: utf-8
require 'pathname'
require 'net/http'
require 'uri'
require 'fileutils'
require 'json'
require 'mini_magick'
require 'stringio'

# Глобальные переменные для хранения ссылок на потоки
$thread_running = false
$thread_mutex = Mutex.new
$test_thread_running = false
$test_thread_mutex = Mutex.new

Rozario::App.controllers :api do

  before do
    response['Cache-Control'] = 'no-store, no-cache, must-revalidate, proxy-revalidate'
    response['Pragma'] = 'no-cache'
    response['Expires'] = '0'
  end

  get :process_image_links do
    content_type :text
    result = []
    ProductComplect.all.each { |x|
      next if x.all_images.nil? || x.all_images.strip == '' || x.all_images == '[]' # Проверяем, что `all_images` не пустой и не nil
      result = processing_all_images(JSON.parse(x.all_images), x.id_1C, overwrite=false)
    }
    return result.join("\n")
  end

  # get "test" do
  #   content_type :json
  #   # product_complect = ProductComplect.find(id_1C: "feb2a6ea-b29c-11e8-8146-52540077d4fc")
  #   # product_complect = ProductComplect.find(product_id: 3071)
  #   product_complect = ProductComplect.where(id_1C: "feb2a6ea-b29c-11e8-8146-52540077d4fc").first
  #   return product_complect.to_json
  # end

  # get "duplicates_id" do
  #   content_type :json
  #   result = []
  #   products = Product.all
  #   duplicates = products
  #     .group_by(&:header)
  #     .select { |header, items| items.size > 1 }
  #     .values
  #     .flatten
  #     .map(&:id)
  #   result = duplicates
  #   # Product.all.each { |x|
  #   #   Product.all.each { |y|
  #   #     if x.header == y.header and x.id != y.id
  #   #       result.append(x.id)
  #   #       break
  #   #     end
  #   #   }
  #   # }
  #   # result = Product # Группируем записи по header и выбираем те, у которых count > 1
  #   #   .select(:id, :header)
  #   #   .group(:header)
  #   #   .having('COUNT(header) > 1')
  #   #   .pluck(:id)
  #   return result.to_json # Возвращаем результат в формате JSON
  # end

  # get "duplicates_names" do
  #   content_type :json
  #   result = []
  #   products = Product.all
  #   duplicates = products
  #     .group_by(&:header)
  #     .select { |header, items| items.size > 1 }
  #     .values
  #     .flatten
  #     .map(&:header) # .map(&:id)
  #   result = duplicates
  #   return result.to_json # Возвращаем результат в формате JSON
  # end

  get :test do
    content_type :text
    result = []
    # ProductComplect.all.each{|x|
    #   if !x.main_image.nil?
    #     if x.main_image.include?("--- []")
    #       a = nil
    #     else
    #       a = x.main_image.nil? ? nil : x.main_image.gsub(/\\u([0-9a-fA-F]{4})/) { |match| [$1.to_i(16)].pack('U') }#JSON.parse(%Q{"#{x.main_image}"})
    #     end
    #   else
    #     a = nil
    #   end
    #   if !x.all_images.nil?
    #     if x.all_images.include?("--- []")
    #       b = nil
    #     else
    #       b = x.all_images.nil? ? nil : x.all_images.gsub(/\\u([0-9a-fA-F]{4})/) { |match| [$1.to_i(16)].pack('U') }#JSON.parse(%Q{"#{x.all_images}"})
    #     end
    #   else
    #     b = nil
    #   end
    #   if !x.discounts.nil?
    #     if x.discounts.include?("--- []")
    #       c = nil
    #     else
    #       c = x.discounts
    #     end
    #   else
    #     c = nil
    #   end
    #   result.append([a, b, c])
    # }
    # return result.to_json

    # ProductComplect.all.each { |x|
    #   if x.discounts != nil
    #     if x.discounts.include?("---")
    #       result.append("#{x.id},#{x.id_1C}")
    #       next
    #     end
    #   end
    #   if x.main_image != nil
    #     if x.main_image.include?("---")
    #       result.append("#{x.id},#{x.id_1C}")
    #       next
    #     end
    #   end
    #   if x.all_images != nil
    #     if x.all_images.include?("---")
    #       result.append("#{x.id},#{x.id_1C}")
    #       next
    #     end
    #   end
    # }
    # return result.join("\n")

    # return "#{PADRINO_ROOT}"
  end

  helpers do
    def processing_all_images(all_images, id_1C, overwrite=true)
      result = []
      
      # Валидация данных изображений
      temp_log = StringIO.new
      unless validate_image_data(all_images, id_1C, temp_log)
        result.append("Ошибка валидации данных изображений: #{temp_log.string}")
        return result
      end

      destination                 = "/srv/rozarioflowers.ru/public/product_images/#{id_1C}/"
      destination_webp            = "/srv/grunt/webp/product_images/#{id_1C}/"
      destination_webp_thumbnails = "/srv/grunt/webp/product_images_thumbnails/#{id_1C}/"

      [destination, destination_webp, destination_webp_thumbnails].each { |path| Pathname.new(path).mkpath } # Создаём нужные папки

      all_images.each_with_index { |img, img_index| # Обрабатываем каждое изображение из JSON
        begin
          uri = URI.parse(img['url']); path = uri.path # Разбираем URL на компоненты
          filename = File.basename(path)
          file_path = File.join(destination, filename)
          webp_filename = File.basename(filename, File.extname(filename)) + '.webp'
          webp_filepath = File.join(destination_webp, webp_filename)
          webp_thumbnail_filepath = File.join(destination_webp_thumbnails, webp_filename)

          if !File.exist?(file_path) || overwrite
            # Улучшенное скачивание с retry логикой
            download_success = false
            max_download_attempts = 3
            
            (1..max_download_attempts).each do |attempt|
              begin
                http = Net::HTTP.new(uri.host, uri.port)
                http.use_ssl = (uri.scheme == 'https')
                configure_http_timeouts(http, 10, 30)
                
                start_time = Time.now
                get_request = Net::HTTP::Get.new(uri.request_uri)
                get_request['User-Agent'] = 'RozarioFlowers-ImageBot/1.0'
                
                response = http.request(get_request)
                download_time = ((Time.now - start_time) * 1000).round(2)
                
                if response.code.to_i == 200
                  image_data = response.body
                  
                  # Проверка размера файла
                  if image_data.bytesize > 10 * 1024 * 1024
                    result.append("Ошибка: изображение #{filename} слишком большое (#{(image_data.bytesize.to_f / (1024*1024)).round(2)}МБ)")
                    break
                  end
                  
                  # Атомарная запись файла
                  temp_file_path = "#{file_path}.tmp"
                  File.open(temp_file_path, 'wb') { |f| f.write(image_data) }
                  File.rename(temp_file_path, file_path)
                  
                  result.append("✓ Скачан #{filename} (#{(image_data.bytesize.to_f / 1024).round(1)}КБ, #{download_time}ms)")
                  download_success = true
                  break
                  
                elsif is_retryable_http_status?(response.code.to_i) && attempt < max_download_attempts
                  result.append("⚠️ Попытка #{attempt}: HTTP #{response.code} для #{filename}, повторяем...")
                  sleep(calculate_retry_delay(attempt, 1, 5))
                  next
                else
                  result.append("❌ Ошибка скачивания #{filename}: HTTP #{response.code}")
                  break
                end
                
              rescue => e
                if is_retryable_error?(e) && attempt < max_download_attempts
                  result.append("⚠️ Попытка #{attempt}: #{e.class.name} для #{filename}, повторяем...")
                  sleep(calculate_retry_delay(attempt, 1, 5))
                  next
                else
                  result.append("❌ Критическая ошибка скачивания #{filename}: #{e.message}")
                  break
                end
              ensure
                # Очистка временных файлов
                temp_file_path = "#{file_path}.tmp"
                File.delete(temp_file_path) if File.exist?(temp_file_path)
              end
            end
            
            # Пропускаем обработку если скачивание не удалось
            unless download_success
              next
            end
            
            # Валидация сохраненного файла
            validation_result = validate_file_safety(file_path)
            unless validation_result[:valid]
              File.delete(file_path) if File.exist?(file_path)
              result.append("❌ Ошибка валидации файла #{filename}: #{validation_result[:error]}")
              next
            end
          end

          if !File.exist?(webp_filepath) || overwrite # Конвертипровать в WebP
            begin
              image = MiniMagick::Image.open(file_path)
              image.format 'webp'
              image.write(webp_filepath)
            rescue MiniMagick::Error => e
              result.append("Ошибка конвертации в WebP #{filename}: #{e.message}")
              next
            end
          end

          if !File.exist?(webp_thumbnail_filepath) || overwrite # Создать миниатюру (thumbnail)
            begin
              create_thumbnail(webp_filepath, webp_thumbnail_filepath, 300)
              result.append("Обработано изображение: #{filename}")
            rescue => e
              result.append("Ошибка создания миниатюры #{filename}: #{e.message}")
            end
          end
        rescue => e
          result.append("Ошибка обработки изображения #{img['url']}: #{e.message}")
        end
      }
      return result
    end
    def create_thumbnail(source_path, destination_path, size) # Метод для создания миниатюры
      image = MiniMagick::Image.open(source_path)
      image.resize "#{size}x#{size}>"
      image.write(destination_path)
    end

    # === VALIDATION HELPERS ===
    
    def validate_1c_response_structure(response_data, log)
      required_fields = ['etag', 'data', 'pending', 'updated_at']
      missing_fields = required_fields.select { |field| !response_data.key?(field) }
      
      if !missing_fields.empty?
        log.puts "[VALIDATION ERROR] Missing required fields in 1C response: #{missing_fields.join(', ')}"
        return false
      end
      
      unless response_data['data'].is_a?(Array)
        log.puts "[VALIDATION ERROR] 'data' field must be an array, got: #{response_data['data'].class}"
        return false
      end
      
      unless response_data['pending'].to_s.match?(/^\d+$/)
        log.puts "[VALIDATION ERROR] 'pending' field must be a number, got: #{response_data['pending']}"
        return false
      end
      
      log.puts "[VALIDATION OK] 1C response structure is valid"
      return true
    end
    
    def validate_product_data(product_data, index, log)
      required_fields = {
        'product_id' => { type: String, max_length: 100 },
        'title' => { type: String, max_length: 500 },
        'text' => { type: String, max_length: 10000 },
        'categories' => { type: String, max_length: 1000 },
        'price' => { type: [String, Numeric], max_value: 999999.99 }
      }
      
      optional_fields = {
        'size' => { type: String, max_length: 200 },
        'package' => { type: String, max_length: 500 },
        'components' => { type: String, max_length: 2000 },
        'color' => { type: String, max_length: 100 },
        'recipient' => { type: String, max_length: 200 },
        'reason' => { type: String, max_length: 200 },
        'price_1990' => { type: [String, Numeric], max_value: 999999.99 },
        'price_2890' => { type: [String, Numeric], max_value: 999999.99 },
        'price_3790' => { type: [String, Numeric], max_value: 999999.99 },
        'discounts' => { type: [String, Array, Hash] },
        'main_image' => { type: [String, Array, Hash] },
        'all_images' => { type: [String, Array] }
      }
      
      # Проверка обязательных полей
      required_fields.each do |field, rules|
        if !product_data.key?(field) || product_data[field].nil? || product_data[field].to_s.strip.empty?
          log.puts "[VALIDATION ERROR][ITEM #{index + 1}] Missing required field: #{field}"
          return false
        end
        
        unless validate_field_type_and_constraints(product_data[field], field, rules, index, log)
          return false
        end
      end
      
      # Проверка опциональных полей
      optional_fields.each do |field, rules|
        if product_data.key?(field) && !product_data[field].nil?
          unless validate_field_type_and_constraints(product_data[field], field, rules, index, log)
            return false
          end
        end
      end
      
      # Дополнительные проверки
      unless validate_product_id_format(product_data['product_id'], index, log)
        return false
      end
      
      unless validate_categories_format(product_data['categories'], index, log)
        return false
      end
      
      unless validate_title_format(product_data['title'], index, log)
        return false
      end
      
      log.puts "[VALIDATION OK][ITEM #{index + 1}] Product data is valid for ID: #{product_data['product_id']}"
      return true
    end
    
    def validate_field_type_and_constraints(value, field_name, rules, index, log)
      # Проверка типа
      allowed_types = Array(rules[:type])
      unless allowed_types.any? { |type| value.is_a?(type) }
        log.puts "[VALIDATION ERROR][ITEM #{index + 1}] Field '#{field_name}' must be #{allowed_types.map(&:name).join(' or ')}, got: #{value.class.name}"
        return false
      end
      
      # Проверка максимальной длины для строк
      if rules[:max_length] && value.is_a?(String) && value.length > rules[:max_length]
        log.puts "[VALIDATION ERROR][ITEM #{index + 1}] Field '#{field_name}' exceeds maximum length of #{rules[:max_length]} characters (got: #{value.length})"
        return false
      end
      
      # Проверка максимального значения для чисел
      if rules[:max_value] && (value.is_a?(Numeric) || value.to_s.match?(/^\d+(\.\d+)?$/)) && value.to_f > rules[:max_value]
        log.puts "[VALIDATION ERROR][ITEM #{index + 1}] Field '#{field_name}' exceeds maximum value of #{rules[:max_value]} (got: #{value})"
        return false
      end
      
      return true
    end
    
    def validate_product_id_format(product_id, index, log)
      # 1С ID должен быть в определенном формате
      unless product_id.match?(/^[a-zA-Z0-9_-]+$/)
        log.puts "[VALIDATION ERROR][ITEM #{index + 1}] Product ID contains invalid characters: #{product_id}"
        return false
      end
      
      return true
    end
    
    def validate_categories_format(categories, index, log)
      # Категории разделены точкой с запятой
      category_list = categories.split(';')
      
      if category_list.empty?
        log.puts "[VALIDATION ERROR][ITEM #{index + 1}] Categories cannot be empty"
        return false
      end
      
      category_list.each do |category|
        category_name = category.strip
        if category_name.empty?
          log.puts "[VALIDATION ERROR][ITEM #{index + 1}] Found empty category in list: #{categories}"
          return false
        end
        
        if category_name.length > 100
          log.puts "[VALIDATION ERROR][ITEM #{index + 1}] Category name too long: #{category_name}"
          return false
        end
      end
      
      return true
    end
    
    def validate_title_format(title, index, log)
      # Заголовок должен содержать тип комплекта в скобках
      bracket_matches = title.scan(/.*?\(([^)]+)\)/)
      
      if bracket_matches.empty?
        log.puts "[VALIDATION ERROR][ITEM #{index + 1}] Title must contain complect type in brackets: #{title}"
        return false
      end
      
      complect_type = bracket_matches.last[0].strip
      if complect_type.empty?
        log.puts "[VALIDATION ERROR][ITEM #{index + 1}] Complect type in brackets cannot be empty: #{title}"
        return false
      end
      
      return true
    end
    
    def validate_image_data(all_images, id_1C, log)
      unless all_images.is_a?(Array)
        log.puts "[VALIDATION ERROR] Images data must be an array for product #{id_1C}, got: #{all_images.class}"
        return false
      end
      
      if all_images.length > 50  # Ограничение на количество изображений
        log.puts "[VALIDATION ERROR] Too many images for product #{id_1C}: #{all_images.length} (max: 50)"
        return false
      end
      
      all_images.each_with_index do |img_data, index|
        unless validate_single_image_data(img_data, id_1C, index, log)
          return false
        end
      end
      
      log.puts "[VALIDATION OK] Images data is valid for product #{id_1C} (#{all_images.length} images)"
      return true
    end
    
    def validate_single_image_data(img_data, id_1C, index, log)
      unless img_data.is_a?(Hash)
        log.puts "[VALIDATION ERROR] Image data must be a hash for product #{id_1C}, image #{index + 1}, got: #{img_data.class}"
        return false
      end
      
      unless img_data.key?('url') && img_data['url'].is_a?(String) && !img_data['url'].strip.empty?
        log.puts "[VALIDATION ERROR] Image must have valid URL for product #{id_1C}, image #{index + 1}"
        return false
      end
      
      url = img_data['url'].strip
      
      # Проверка URL формата
      begin
        uri = URI.parse(url)
        unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
          log.puts "[VALIDATION ERROR] Image URL must be HTTP/HTTPS for product #{id_1C}, image #{index + 1}: #{url}"
          return false
        end
      rescue URI::InvalidURIError => e
        log.puts "[VALIDATION ERROR] Invalid image URL for product #{id_1C}, image #{index + 1}: #{url} - #{e.message}"
        return false
      end
      
      # Проверка расширения файла
      allowed_extensions = %w[.jpg .jpeg .png .gif .bmp .webp]
      file_extension = File.extname(URI.parse(url).path).downcase
      
      unless allowed_extensions.include?(file_extension)
        log.puts "[VALIDATION ERROR] Unsupported image format for product #{id_1C}, image #{index + 1}: #{file_extension} (allowed: #{allowed_extensions.join(', ')})"
        return false
      end
      
      # Проверка имени файла на безопасность
      filename = File.basename(URI.parse(url).path)
      if filename.include?('..') || filename.include?('/') || filename.include?('\\')
        log.puts "[VALIDATION ERROR] Unsafe filename for product #{id_1C}, image #{index + 1}: #{filename}"
        return false
      end
      
      return true
    end
    
    def validate_file_safety(file_path, max_size_mb = 10)
      unless File.exist?(file_path)
        return { valid: false, error: "File does not exist: #{file_path}" }
      end
      
      file_size_mb = File.size(file_path).to_f / (1024 * 1024)
      if file_size_mb > max_size_mb
        return { valid: false, error: "File too large: #{file_size_mb.round(2)}MB (max: #{max_size_mb}MB)" }
      end
      
      # Проверка MIME типа с помощью MiniMagick
      begin
        image = MiniMagick::Image.open(file_path)
        allowed_formats = %w[JPEG PNG GIF BMP WEBP]
        unless allowed_formats.include?(image.type)
          return { valid: false, error: "Unsupported image format: #{image.type}" }
        end
        
        # Проверка разрешения
        if image.width > 5000 || image.height > 5000
          return { valid: false, error: "Image dimensions too large: #{image.width}x#{image.height} (max: 5000x5000)" }
        end
        
      rescue MiniMagick::Error => e
        return { valid: false, error: "Invalid image file: #{e.message}" }
      end
      
      return { valid: true }
    end
    # === ERROR HANDLING & RETRY HELPERS ===
    
    # Circuit Breaker Pattern для предотвращения каскадных ошибок
    @@circuit_breaker_state = :closed # :closed, :open, :half_open
    @@circuit_breaker_failures = 0
    @@circuit_breaker_last_failure_time = nil
    @@circuit_breaker_mutex = Mutex.new
    
    CIRCUIT_BREAKER_FAILURE_THRESHOLD = 5
    CIRCUIT_BREAKER_TIMEOUT = 60 # секунд
    
    def circuit_breaker_call(operation_name, log = nil)
      @@circuit_breaker_mutex.synchronize do
        case @@circuit_breaker_state
        when :closed
          # Нормальное состояние - выполняем операцию
          begin
            result = yield
            # Сброс счетчика при успешном выполнении
            @@circuit_breaker_failures = 0
            return result
          rescue => e
            @@circuit_breaker_failures += 1
            @@circuit_breaker_last_failure_time = Time.now
            
            if @@circuit_breaker_failures >= CIRCUIT_BREAKER_FAILURE_THRESHOLD
              @@circuit_breaker_state = :open
              log&.puts "[CIRCUIT_BREAKER] ❌ Circuit открыт для '#{operation_name}' (#{@@circuit_breaker_failures} ошибок)"
            else
              log&.puts "[CIRCUIT_BREAKER] ⚠️ Ошибка #{@@circuit_breaker_failures}/#{CIRCUIT_BREAKER_FAILURE_THRESHOLD} для '#{operation_name}'"
            end
            
            raise e
          end
          
        when :open
          # Circuit открыт - проверяем таймаут
          if Time.now - @@circuit_breaker_last_failure_time > CIRCUIT_BREAKER_TIMEOUT
            @@circuit_breaker_state = :half_open
            log&.puts "[CIRCUIT_BREAKER] ♾️ Переход в half-open для '#{operation_name}'"
            # Пробуем выполнить операцию
            begin
              result = yield
              @@circuit_breaker_state = :closed
              @@circuit_breaker_failures = 0
              log&.puts "[CIRCUIT_BREAKER] ✓ Circuit закрыт для '#{operation_name}' - операция успешна"
              return result
            rescue => e
              @@circuit_breaker_state = :open
              @@circuit_breaker_last_failure_time = Time.now
              log&.puts "[CIRCUIT_BREAKER] ❌ Circuit снова открыт для '#{operation_name}'"
              raise e
            end
          else
            remaining_time = CIRCUIT_BREAKER_TIMEOUT - (Time.now - @@circuit_breaker_last_failure_time)
            error_msg = "Circuit breaker открыт для '#{operation_name}'. Повтор через #{remaining_time.round(1)}с"
            log&.puts "[CIRCUIT_BREAKER] ⛔ #{error_msg}"
            raise StandardError.new(error_msg)
          end
          
        when :half_open
          # Пробуем одну операцию
          begin
            result = yield
            @@circuit_breaker_state = :closed
            @@circuit_breaker_failures = 0
            log&.puts "[CIRCUIT_BREAKER] ✓ Circuit закрыт для '#{operation_name}' после half-open"
            return result
          rescue => e
            @@circuit_breaker_state = :open
            @@circuit_breaker_last_failure_time = Time.now
            log&.puts "[CIRCUIT_BREAKER] ❌ Circuit открыт для '#{operation_name}' из half-open"
            raise e
          end
        end
      end
    end
    
    def configure_http_timeouts(http, connect_timeout = 10, read_timeout = 30)
      http.open_timeout = connect_timeout
      http.read_timeout = read_timeout
      http.ssl_timeout = connect_timeout if http.use_ssl?
      
      # Дополнительные настройки для стабильности
      http.keep_alive_timeout = 2
    end
    
    def is_retryable_error?(error)
      retryable_errors = [
        Net::TimeoutError,
        Net::ReadTimeout, 
        Net::OpenTimeout,
        Net::ConnectTimeout,
        Timeout::Error,
        Errno::ECONNREFUSED,
        Errno::ECONNRESET,
        Errno::ECONNABORTED,
        Errno::EHOSTUNREACH,
        Errno::ENETUNREACH,
        Errno::ETIMEDOUT,
        SocketError
      ]
      
      retryable_errors.any? { |err_class| error.is_a?(err_class) }
    end
    
    def is_retryable_http_status?(status_code)
      # 5xx ошибки сервера и 429 Too Many Requests
      retryable_statuses = [408, 429, 500, 502, 503, 504, 507, 509, 510, 511]
      retryable_statuses.include?(status_code)
    end
    
    def calculate_retry_delay(attempt, base_delay = 1, max_delay = 30)
      # Экспоненциальная задержка с jitter
      delay = [base_delay * (2 ** (attempt - 1)), max_delay].min
      jitter = Random.rand(0.1..0.3) * delay
      (delay + jitter).round(2)
    end
    
    def log_retry_attempt(log, attempt, max_attempts, error, context = "")
      log.puts "[RETRY][#{context}] Attempt #{attempt}/#{max_attempts} failed: #{error.class.name}: #{error.message}"
      if attempt < max_attempts
        delay = calculate_retry_delay(attempt)
        log.puts "[RETRY][#{context}] Retrying in #{delay} seconds..."
      else
        log.puts "[RETRY][#{context}] All retry attempts exhausted"
      end
    end
    
    def enhanced_http_request(http, request, max_attempts = 3, context = "", log = nil)
      configure_http_timeouts(http)
      
      (1..max_attempts).each do |attempt|
        begin
          start_time = Time.now
          response = http.request(request)
          duration = ((Time.now - start_time) * 1000).round(2)
          
          log&.puts "[HTTP][#{context}] Request completed in #{duration}ms (attempt #{attempt})"
          
          # Проверяем статус ответа
          status_code = response.code.to_i
          
          if response.is_a?(Net::HTTPSuccess)
            log&.puts "[HTTP][#{context}] ✓ Success: HTTP #{status_code}"
            return response
          elsif is_retryable_http_status?(status_code) && attempt < max_attempts
            log&.puts "[HTTP][#{context}] ⚠️ Retryable HTTP status: #{status_code}"
            delay = calculate_retry_delay(attempt)
            sleep(delay)
            next
          else
            log&.puts "[HTTP][#{context}] ❌ Non-retryable HTTP status: #{status_code}"
            return response
          end
          
        rescue => error
          log_retry_attempt(log, attempt, max_attempts, error, context) if log
          
          if is_retryable_error?(error) && attempt < max_attempts
            delay = calculate_retry_delay(attempt)
            sleep(delay)
            next
          elsif attempt == max_attempts
            # Создаем ошибку ответа для последней попытки
            return create_error_response(error, context)
          end
        end
      end
    end
    
    def create_error_response(error, context = "")
      case error
      when Net::TimeoutError, Net::ReadTimeout, Net::OpenTimeout, Net::ConnectTimeout, Timeout::Error
        response = Net::HTTPRequestTimeOut.new('1.1', '408', 'Request Timeout')
        response.instance_variable_set(:@body, JSON.generate({
          error: 'timeout',
          message: "Request timeout in #{context}: #{error.message}",
          error_class: error.class.name
        }))
      when Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ECONNABORTED
        response = Net::HTTPServiceUnavailable.new('1.1', '503', 'Service Unavailable')
        response.instance_variable_set(:@body, JSON.generate({
          error: 'connection_refused',
          message: "Connection failed in #{context}: #{error.message}",
          error_class: error.class.name
        }))
      when Errno::EHOSTUNREACH, Errno::ENETUNREACH
        response = Net::HTTPServiceUnavailable.new('1.1', '503', 'Service Unavailable')
        response.instance_variable_set(:@body, JSON.generate({
          error: 'network_unreachable',
          message: "Network unreachable in #{context}: #{error.message}",
          error_class: error.class.name
        }))
      else
        response = Net::HTTPInternalServerError.new('1.1', '500', 'Internal Server Error')
        response.instance_variable_set(:@body, JSON.generate({
          error: 'unknown',
          message: "Unknown error in #{context}: #{error.message}",
          error_class: error.class.name
        }))
      end
      
      response
    end
    
    def recursive_http_request(http, request, attempts_number)
      # Обратная совместимость с старым API
      enhanced_http_request(http, request, attempts_number, "legacy", nil)
    end
    def transliterate(text)
      transliteration_map = {
        'А' => 'A', 'Б' => 'B', 'В' => 'V', 'Г' => 'G', 'Д' => 'D', 'Е' => 'E', 'Ё' => 'E',
        'Ж' => 'Zh', 'З' => 'Z', 'И' => 'I', 'Й' => 'Y', 'К' => 'K', 'Л' => 'L', 'М' => 'M',
        'Н' => 'N', 'О' => 'O', 'П' => 'P', 'Р' => 'R', 'С' => 'S', 'Т' => 'T', 'У' => 'U',
        'Ф' => 'F', 'Х' => 'Kh', 'Ц' => 'Ts', 'Ч' => 'Ch', 'Ш' => 'Sh', 'Щ' => 'Shch',
        'Ъ' => '', 'Ы' => 'Y', 'Ь' => '', 'Э' => 'E', 'Ю' => 'Yu', 'Я' => 'Ya',
        'а' => 'a', 'б' => 'b', 'в' => 'v', 'г' => 'g', 'д' => 'd', 'е' => 'e', 'ё' => 'e',
        'ж' => 'zh', 'з' => 'z', 'и' => 'i', 'й' => 'y', 'к' => 'k', 'л' => 'l', 'м' => 'm',
        'н' => 'n', 'о' => 'o', 'п' => 'p', 'р' => 'r', 'с' => 's', 'т' => 't', 'у' => 'u',
        'ф' => 'f', 'х' => 'kh', 'ц' => 'ts', 'ч' => 'ch', 'ш' => 'sh', 'щ' => 'shch',
        'ъ' => '', 'ы' => 'y', 'ь' => '', 'э' => 'e', 'ю' => 'yu', 'я' => 'ya'
      }
      text.chars.map { |char| transliteration_map[char] || char }.join
    end
    def to_slug(str)
      str = transliterate(str)
      return str.gsub(' ', '-').gsub(/[^\w-]/, '').downcase
    end
    def crud_product_complects_transaction(data, log)
      begin
        log.puts "[TRANSACTION START] Обработка #{data.length} товаров от 1С"
        processed_count = 0
        created_count = 0
        updated_count = 0
        error_count = 0
        
        ActiveRecord::Base.transaction do
          data.each_with_index { |x, index|
            # Валидация данных товара
            unless validate_product_data(x, index, log)
              log.puts "[ITEM #{index + 1}] ❌ SKIPPED: Некорректные данные товара"
              error_count += 1
              processed_count += 1
              next
            end
            
            str = x['title']
            product_1c_id = x['product_id']
            
            log.puts "[ITEM #{index + 1}/#{data.length}] 1С ID: #{product_1c_id}, Title: '#{str}'"
            
            # Получить все названия комплектов с кешированием
            @complects_cache ||= Complect.all.map(&:header)
            substrings = @complects_cache
            
            if substrings.any? { |substring| str.include?(substring) } # Если указанный в заголовке тип комплекта зарегистирован...
              log.puts "[ITEM #{index + 1}] ✓ Найден соответствующий тип комплекта в заголовке"
              
              product_complect = ProductComplect.where(id_1C: product_1c_id).first # Найти комплект по id_1C
              if product_complect.nil? # Если НЕ найден, то создать новый...
                log.puts "[ITEM #{index + 1}] → СОЗДАНИЕ нового продукта"
                
                # Извлечь тип комплекта из скобок
                bracket_matches = str.scan(/.*?\(([^)]+)\)/)
                if bracket_matches.empty?
                  log.puts "[ITEM #{index + 1}] ❌ ERROR: Не удалось извлечь тип комплекта из скобок в '#{str}'"
                  error_count += 1
                  next
                end
                
                last_bracket_text = bracket_matches.last[0].strip
                log.puts "[ITEM #{index + 1}] Извлечен тип комплекта: '#{last_bracket_text}'"
                
                complect = Complect.where(header: last_bracket_text).first # Найти тип комплекта
                if complect.nil?
                  log.puts "[ITEM #{index + 1}] ❌ ERROR: Тип комплекта '#{last_bracket_text}' не найден в БД"
                  log.puts "[ITEM #{index + 1}] Доступные типы комплектов: #{substrings.join(', ')}"
                  error_count += 1
                  next
                end
                
                log.puts "[ITEM #{index + 1}] ✓ Найден комплект ID #{complect.id}: '#{complect.header}'"
                
                # Обработка изображений
                if x['all_images'] && !x['all_images'].empty?
                  log.puts "[ITEM #{index + 1}] → Обработка #{x['all_images'].length rescue 'N/A'} изображений"
                  image_results = processing_all_images(x['all_images'], product_1c_id)
                  image_results.each { |result| log.puts "[ITEM #{index + 1}] #{result}" }
                end
                
                # Создание продукта
                product = Product.new
                product_header = x['title'].strip.gsub(/ *\([^)]+\)$/, '').strip
                product.header = product_header
                original_slug = to_slug(product_header)
                product.slug = original_slug
                product.rating = 5
                
                log.puts "[ITEM #{index + 1}] Создаем Product: header='#{product_header}', slug='#{original_slug}'"
                
                # Проверка на дубликаты slug'а
                existing_slug_count = Product.where(slug: original_slug).count
                if existing_slug_count > 0
                  log.puts "[ITEM #{index + 1}] ⚠️ WARNING: Найдено #{existing_slug_count} товаров с таким же slug '#{original_slug}'"
                  
                  # Генерируем уникальный slug
                  counter = 1
                  while Product.where(slug: product.slug).exists?
                    product.slug = "#{original_slug}-#{counter}"
                    counter += 1
                  end
                  log.puts "[ITEM #{index + 1}] → Скорректирован slug на '#{product.slug}'"
                end
                
                # Проверка на дубликаты header'а
                existing_header_count = Product.where(header: product_header).count
                if existing_header_count > 0
                  log.puts "[ITEM #{index + 1}] ⚠️ WARNING: Найдено #{existing_header_count} товаров с таким же заголовком '#{product_header}'"
                end
                
                if product.save
                    x['categories'].split(';').each { |category_name|
                      category = Category.where(title: category_name.strip).first
                      if category # Используются только существующие категории, в противном случае пропускаем...
                        bound = CategoriesProducts.new
                        bound.product_id = product.id
                        bound.category_id = category.id
                        bound.save
                      end
                    }
                    product_complect = ProductComplect.new
                    product_complect.product_id  = product.id
                    product_complect.complect_id = complect.id
                    product_complect.id_1C       = x['product_id']
                    product_complect.text        = x['text']
                    product_complect.size        = x['size']
                    product_complect.package     = x['package']
                    product_complect.components  = x['components']
                    product_complect.color       = x['color']
                    product_complect.categories  = x['categories']
                    product_complect.recipient   = x['recipient']
                    product_complect.reason      = x['reason']
                    product_complect.price       = x['price']
                    product_complect.price_1990  = x['price_1990']
                    product_complect.price_2890  = x['price_2890']
                    product_complect.price_3790  = x['price_3790']
                    product_complect.discounts   = x['discounts'].to_json
                    product_complect.main_image  = x['main_image'].to_json
                    product_complect.all_images  = x['all_images'].to_json
                    if !product_complect.save
                      log.puts "[ITEM #{index + 1}] ❌ PRODUCT_COMPLECT SAVE FAILED for 1С ID: #{product_1c_id}"
                      log.puts "[ITEM #{index + 1}] ❌ ProductComplect validation errors: #{product_complect.errors.full_messages.join('; ')}"
                      log.puts "[ITEM #{index + 1}] ❌ ProductComplect attributes:"
                      product_complect.attributes.each { |key, value| log.puts "[ITEM #{index + 1}]   #{key}: #{value.inspect}" if value }
                      error_count += 1
                      next
                    else
                      log.puts "[ITEM #{index + 1}] ✓ ProductComplect created successfully ID: #{product_complect.id}"
                      created_count += 1
                    end
                  else
                    log.puts "[ITEM #{index + 1}] ❌ PRODUCT SAVE FAILED for 1С ID: #{product_1c_id}"
                    log.puts "[ITEM #{index + 1}] ❌ Product validation errors: #{product.errors.full_messages.join('; ')}"
                    log.puts "[ITEM #{index + 1}] ❌ Product attributes:"
                    product.attributes.each { |key, value| log.puts "[ITEM #{index + 1}]   #{key}: #{value.inspect}" }
                    log.puts "[ITEM #{index + 1}] ❌ Database constraints check:"
                    log.puts "[ITEM #{index + 1}]   - Products with same header: #{Product.where(header: product_header).count}"
                    log.puts "[ITEM #{index + 1}]   - Products with same slug: #{Product.where(slug: product.slug).count}"
                    log.puts "[ITEM #{index + 1}]   - Encoding check: header is valid UTF-8: #{product_header.valid_encoding?}"
                    log.puts "[ITEM #{index + 1}]   - Encoding check: slug is valid UTF-8: #{product.slug.valid_encoding?}"
                    error_count += 1
                    next
                  end
              else # ...иначе обновить данные.
                log.puts "[ITEM #{index + 1}] → ОБНОВЛЕНИЕ существующего продукта (ProductComplect ID: #{product_complect.id})"
                product = Product.where(id: product_complect.product_id).first
                if product.nil?
                  log.puts "[ITEM #{index + 1}] ❌ ERROR: Product не найден по ID #{product_complect.product_id} для ProductComplect ID #{product_complect.id}"
                  error_count += 1
                  next
                end
                
                log.puts "[ITEM #{index + 1}] ✓ Найден Product ID #{product.id}: '#{product.header}'"
                
                if product
                  x['categories'].split(';').each { |category_name|
                    category = Category.where(title: category_name.strip).first
                    if category
                      if CategoriesProducts.where(product_id: product.id, category_id: category.id).first.nil?
                        bound = CategoriesProducts.new
                        bound.product_id = product.id
                        bound.category_id = category.id
                        bound.save
                      end
                    end
                  }
                  old_header = product.header
                  product_name = x['title'].strip.gsub(/ *\([^)]+\)$/, '').strip
                  product.header = product_name
                  
                  if old_header != product_name
                    log.puts "[ITEM #{index + 1}] → Изменение заголовка: '#{old_header}' → '#{product_name}'"
                  end
                  product_complect.text       = x['text']
                  product_complect.size       = x['size']
                  product_complect.package    = x['package']
                  product_complect.components = x['components']
                  product_complect.color      = x['color']
                  product_complect.categories = x['categories']
                  product_complect.recipient  = x['recipient']
                  product_complect.reason     = x['reason']
                  product_complect.price      = x['price']
                  product_complect.price_1990 = x['price_1990']
                  product_complect.price_2890 = x['price_2890']
                  product_complect.price_3790 = x['price_3790']
                  product_complect.discounts  = x['discounts'].to_json
                  product_complect.main_image = x['main_image'].to_json
                  product_complect.all_images = x['all_images'].to_json
                  if !product_complect.save
                    log.puts "[ITEM #{index + 1}] ❌ UPDATE FAILED: ProductComplect не сохранен для 1С ID: #{product_1c_id}"
                    log.puts "[ITEM #{index + 1}] ❌ Update validation errors: #{product_complect.errors.full_messages.join('; ')}"
                    error_count += 1
                    next
                  else
                    log.puts "[ITEM #{index + 1}] ✓ ProductComplect updated successfully"
                    updated_count += 1
                  end
              end
              end
            else
              log.puts "[ITEM #{index + 1}] ⚠️ SKIPPED: Заголовок не содержит ни одного известного типа комплекта"
              log.puts "[ITEM #{index + 1}] Доступные типы: #{substrings.join(', ')}"
            end
            
            processed_count += 1
          }
        end
        log.puts "[TRANSACTION SUCCESS] Обработано: #{processed_count}, Создано: #{created_count}, Обновлено: #{updated_count}, Ошибок: #{error_count}"
        return true # Транзакция успешно завершена
      rescue ActiveRecord::RecordInvalid => e
        log.puts "[TRANSACTION ERROR] Ошибка валидации записи: #{e.message}"
        log.puts "[TRANSACTION ERROR] Record: #{e.record.class.name} #{e.record.inspect}"
        log.puts "[TRANSACTION ERROR] Validation errors: #{e.record.errors.full_messages.join('; ')}"
        log.puts "[TRANSACTION ERROR] Stacktrace (first 10 lines):"
        e.backtrace.first(10).each { |line| log.puts "[TRANSACTION ERROR]   #{line}" }
        return false # Ошибка валидации
      rescue StandardError => e
        log.puts "[TRANSACTION ERROR] Ошибка во время транзакции: #{e.class.name}: #{e.message}"
        log.puts "[TRANSACTION ERROR] Current processing stats - Processed: #{processed_count rescue 0}, Created: #{created_count rescue 0}, Updated: #{updated_count rescue 0}, Errors: #{error_count rescue 0}"
        log.puts "[TRANSACTION ERROR] Stacktrace (first 10 lines):"
        e.backtrace.first(10).each { |line| log.puts "[TRANSACTION ERROR]   #{line}" }
        return false  # Общая ошибка транзакции
      end
    end
  end

  get :all_id_1C do
    content_type :text
    result = []
    ProductComplect.all.each { |x|
      if x.id_1C != nil
        result.append("#{x.id},#{x.id_1C}")
      end
    }
    return result.join("\n")
  end

  get 'thread_list' do
    content_type :text
    result = []
    Thread.list.each { |t| result << t.inspect }
    return result.join("\n")
  end

  get 'mutex_test' do
    content_type :json
    if $test_thread_mutex.synchronize { $test_thread_running } # Проверяем, запущен ли поток
      status 409 # Конфликт
      return {message: "The process is already underway", status: "error"}.to_json
    end
    begin
      thread = Thread.new do
        begin
          $test_thread_mutex.synchronize { $test_thread_running = true }
          sleep 5
        ensure
          $test_thread_mutex.synchronize { $test_thread_running = false } # Освобождаем состояние потока после завершения
        end
      end
    rescue => e
      status 500 # Внутренняя ошибка сервера
      return {message: "An error occurred: #{e.message}", status: "error"}.to_json
    end
    return {message: "Operation completed successfully", status: "success"}.to_json
  end

  get '1c_notify_update' do # https://rozarioflowers.ru/api/1c_notify_update
    # curl -u bae15749-52e9-4420-b429-f9fb483f4e48:94036dbc-5bbc-4495-952c-9f2150047b9a -X GET https://rozarioflowers.ru/api/1c_notify_update
    # curl -X POST https://server-1c.rdp.rozarioflowers.ru/exchange/hs/api/prices -H "Content-Type: application/json" -d "{\"etag\": null, \"count\": 512}"
    # curl -X GET https://server-1c.rdp.rozarioflowers.ru/exchange/hs/api/prices/status
    content_type :json

    log_path = "#{PADRINO_ROOT}/log/1c_notify_update.log"

    if $thread_mutex.synchronize { $thread_running } # Проверить, запущен ли поток.
      File.open(log_path, 'a') do |log|
        log.puts "--> #{Time.now} - Конфликт при запуске потока. Поток уже запущен ранее..."
      end
      status 409 # Конфликт.
      return {message: "The process is already underway", status: "error"}.to_json
    end

    begin
      thread = Thread.new do # Создаем новый поток.
        begin
          $thread_mutex.synchronize { $thread_running = true } # Установить флаг потока как запущенный.
          File.open(log_path, 'a') do |log| # Открываем лог-файл для записи.
            
            ok = true # Praesumptio.

            # Записываем в лог начало процесса.
            log.puts "Начало процесса..." # Логируем время начала процесса.
            
            url = URI.parse('https://server-1c.rdp.rozarioflowers.ru/exchange/hs/api/prices') # Определить URL для POST запроса.
            
            # Создать объект запроса с улучшенной обработкой ошибок.
            http = Net::HTTP.new(url.host, url.port)
            http.use_ssl = true
            configure_http_timeouts(http, 15, 45) # Увеличенные таймауты для начального запроса
            
            request = Net::HTTP::Post.new(url.path, {
              'Content-Type' => 'application/json',
              'User-Agent' => 'RozarioFlowers/1.0',
              'Accept' => 'application/json'
            })

            n = 512 / 4
            request.body = {'etag': nil, 'count': n}.to_json
            
            log.puts "[HTTP] Отправка начального запроса на 1С сервер..."
            response = enhanced_http_request(http, request, 5, "initial_request", log) # Улучшенная обработка
            response_code = response.code.to_i # Получить код ответа от сервера.

            if response_code == 200 # Если код ответа 200 (успешный)...
              begin
                response_data = JSON.parse(response.body) # Парсим JSON-ответ.
              rescue JSON::ParserError => e
                ok = false
                log.puts "[VALIDATION ERROR] Invalid JSON response from 1C server: #{e.message}"
                log.puts "[VALIDATION ERROR] Response body preview: #{response.body[0..200]}..."
                break
              end
              
              # Валидация структуры ответа
              unless validate_1c_response_structure(response_data, log)
                ok = false
                break
              end
              
              etag       = response_data['etag']       # Извлечь etag из данных из ответа.
              updated_at = response_data['updated_at'] # Извлечь дату обновления из ответа.
              data       = response_data['data']       # Извлечь данные из ответа.
              pending    = response_data['pending'].to_i - data.length # Рассчитать оставшееся количество элементов (не удалось достучаться до разработчика 1С, чтобы реализовать это на стороне сервера).
              log.puts "Код ответа: #{response_code} | data.length: #{data.length} | etag: #{etag == '' || etag.nil? ? 'null' : etag} | updated_at: #{updated_at} | pending: #{pending}" # Логировать полученные данные
              
              if pending < 0
                log.puts "[VALIDATION ERROR] ERROR_gf04s0FV: Negative pending count detected: #{pending}"
                ok = false
                break
              end
              # n = pending if n > pending # Если запрашиваем данных больше, чем имеется в остатке, то скорректировать запрашиваемое число элементов.
              if data.length > 0
                begin
                  log.puts "[INITIAL_BATCH] Обработка #{data.length} товаров..."
                  transaction_start_time = Time.now
                  
                  transaction_result = crud_product_complects_transaction(data, log)
                  
                  transaction_duration = ((Time.now - transaction_start_time) * 1000).round(2)
                  
                  if transaction_result
                    log.puts "[INITIAL_BATCH] ✓ Транзакция успешно завершена за #{transaction_duration}ms"
                  else
                    log.puts "[INITIAL_BATCH] ❌ Ошибка транзакции за #{transaction_duration}ms"
                    ok = false
                  end
                  
                rescue => e
                  transaction_duration = ((Time.now - transaction_start_time) * 1000).round(2) rescue "N/A"
                  log.puts "[INITIAL_BATCH] ❌ Критическая ошибка транзакции (#{transaction_duration}ms): #{e.class.name}: #{e.message}"
                  log.puts "[INITIAL_BATCH] Stacktrace: #{e.backtrace.first(5).join('; ')}"
                  ok = false
                end
                if data.length <= n && pending > 0 # The length of the data array in the response matches the length specified in the query.
                  tail = pending % n # Вычислить остаток данных.
                  log.puts "Tail: #{tail}" # Логировать хвост.
                  n_requests = (pending - tail) / n # Рассчитать количество запросов для получения оставшихся данных.
                  n_requests = n_requests + 1 if tail > 0 # Если есть хвост, то добавить доп. запрос для него.
                  i = 1; failed = 0 # Инициализировать переменные для подсчета запросов и неудачных попыток.
                  log.puts "Ожидается запросов: #{n_requests}" # Логировать количество запросов.
                  while i <= n_requests && i > 0 && !etag.nil? # Пока есть запросы, выполняем их...
                    log.puts "[BATCH] Запрос ##{i}/#{n_requests} (etag: #{etag})"
                    
                    request = Net::HTTP::Post.new(url.path, {
                      'Content-Type' => 'application/json',
                      'User-Agent' => 'RozarioFlowers/1.0',
                      'Accept' => 'application/json'
                    })
                    
                    n = i == n_requests ? tail : n # Последний запрос - запрашиваем остаток
                    request.body = {'etag': etag, 'count': n}.to_json
                    
                    # Меньше повторов для batch запросов
                    response = enhanced_http_request(http, request, 3, "batch_request_#{i}", log)
                    response_code = response.code.to_i # Получить код ответа.
                    if response_code == 200 # Если код ответа 200.
                      begin
                        response_data = JSON.parse(response.body) # Парсить JSON-ответ.
                      rescue JSON::ParserError => e
                        failed += 1
                        log.puts "[VALIDATION ERROR] Invalid JSON in follow-up request #{i}: #{e.message}"
                        next
                      end
                      
                      # Валидация структуры ответа
                      unless validate_1c_response_structure(response_data, log)
                        failed += 1
                        next
                      end
                      
                      data = response_data['data']             # Извлечь данные.
                      etag = response_data['etag']             # Извлечь etag.
                      updated_at = response_data['updated_at'] # Извлечь дату обновления.
                      pending    = response_data['pending'] - data.length # Рассчитать оставшееся количество данных.
                      log.puts "Код ответа: #{response_code} | data.length: #{data.length} | etag: #{etag == '' || etag.nil? ? 'null' : etag} | updated_at: #{updated_at} | pending: #{pending}" # Логировать информацию о полученных данных.
                      begin
                        transaction_success = crud_product_complects_transaction(data, log)
                        if transaction_success
                          log.puts "[BATCH] ✓ Транзакция успешно завершена для batch #{i}"
                          i += 1
                          failed = 0 # Сбросить счетчик ошибок после успеха
                        else
                          failed += 1
                          log.puts "[BATCH] ❌ Транзакция не удалась для batch #{i} (ошибка #{failed}/7)"
                          if failed > 7
                            ok = false
                            log.puts "[BATCH] ❌ Превышен лимит ошибок транзакций, прекращаем обработку"
                            break
                          end
                        end
                      rescue => e
                        failed += 1
                        log.puts "[BATCH] ❌ Критическая ошибка в batch #{i}: #{e.class.name}: #{e.message}"
                        log.puts "[BATCH] Backtrace: #{e.backtrace.first(3).join('; ')}"
                        if failed > 7
                          ok = false
                          break
                        end
                      end
                    else
                      ok = false # Установить флаг ошибки.
                      log.puts "ERROR_d0j8hjoy. Соединение не удалось (2). Код ответа: #{response_code}" # Логировать ошибку соединения.
                    end
                  end
                elsif data.length <= n && pending == 0 # Если данных достаточно и остаток пуст, то...
                  log.puts "Повторных запросов непотребовалось" # ...логировать, что дополнительных запросов не потребовалось.
                elsif data.length > n # Если данных больше, чем требуется, то...
                  ok = false # ...установить флаг ошибки и...
                  log.puts "ERROR_j80oyhjd: Данных в ответе более, чем требовалось." # ...логировать ошибку.
                elsif data.length < n && pending != 0 # Если данных меньше, чем требуется, но есть остаток, то...
                  ok = false # ...установить флаг ошибки и...
                  log.puts "ERROR_b5766b79: Данных в ответе меньше, чем требовалось, имеется остаток." # ...логировать ошибку.
                end
              else
                log.puts "Данных для обработки не поступило."
              end
            else
              ok = false # Установить флаг ошибки.
              log.puts "ERROR_66b79b57. Соединение не удалось (1). Код ответа: #{response_code}" # Логировать ошибку соединения.
            end
            # Уведомление сервера о результате обработки
            begin
              notify_request = Net::HTTP::Post.new(url.path, {
                'Content-Type' => 'application/json',
                'User-Agent' => 'RozarioFlowers/1.0'
              })
              
              if ok
                log.puts "[NOTIFICATION] Отправка уведомления об успешном завершении..."
                notify_request.body = {'etag': etag, 'count': 0}.to_json
              else
                log.puts "[NOTIFICATION] Отправка уведомления об ошибке..."
                notify_request.body = {'error': true}.to_json
              end
              
              notify_response = enhanced_http_request(http, notify_request, 2, "notification", log)
              notify_code = notify_response.code.to_i
              
              if notify_code == 200
                log.puts "[NOTIFICATION] ✓ Сервер успешно уведомлён (ok: #{ok})"
              else
                log.puts "[NOTIFICATION] ❌ Ошибка уведомления: HTTP #{notify_code}"
                if notify_response.body && !notify_response.body.empty?
                  log.puts "[NOTIFICATION] Response: #{notify_response.body[0..200]}..."
                end
              end
              
            rescue => e
              log.puts "[NOTIFICATION] ❌ Критическая ошибка уведомления: #{e.class.name}: #{e.message}"
            end
            log.puts "Конец." # Логировать завершение процесса.
          end
        rescue => e
          File.open(log_path, 'a') do |log|
            log.puts "[THREAD_ERROR] Критическая ошибка в главном потоке: #{e.class.name}: #{e.message}"
            log.puts "[THREAD_ERROR] Stacktrace:"
            e.backtrace.first(10).each_with_index do |line, i|
              log.puts "[THREAD_ERROR]   #{i+1}. #{line}"
            end
          end
        ensure
          File.open(log_path, 'a') do |log|
            log.puts "[THREAD_CLEANUP] Зачистка ресурсов потока..."
            cleanup_start = Time.now
          end
          
          begin
            sleep 3 # Уменьшенная задержка для быстрого респонса
          ensure
            $thread_mutex.synchronize { $thread_running = false }
            
            File.open(log_path, 'a') do |log|
              cleanup_duration = ((Time.now - cleanup_start) * 1000).round(2) rescue "N/A"
              log.puts "[THREAD_CLEANUP] ✓ Поток освобожден за #{cleanup_duration}ms"
            end
          end
        end
      end
    rescue => e
      File.open(log_path, 'a') do |log|
        log.puts "--> #{Time.now} - Общая ошибка при выполнении потока."
      end
      status 500 # Внутренняя ошибка сервера
      return {message: "An error occurred: #{e.message}", status: "error"}.to_json # Вернуть сообщение об ошибке.
    end
    File.open(log_path, 'a') do |log|
      log.puts "--> #{Time.now} - Запущен поток."
    end
    return {message: "Operation completed successfully", status: "success"}.to_json # Вернуть сообщение об успешном начале операции.
  end

  get 'subdomain' do
    content_type :json
    return Subdomain.find_by_url(params['url']).to_json(include: :disabled_dates) if params['url'].present?
    return Subdomain.find_by_id(params['id']).to_json(include: :disabled_dates) if params['id'].present?
    return 401
  end

  post 'newbukety.json' do
    # puts "post 'newbukety.json'"
    jsonr = JSON.parse(request.body.read)
    limit = 4
    page = jsonr['page'] || 0
    @category = Category.find(55)
    categories =
      if jsonr['categories'].blank? || jsonr['categories'].empty?
        Category.where(parent_id: @category.id).select('id').map(&:id)
      else
        jsonr['categories']
      end
    min_price = jsonr['min_price'].blank? ? 0 : jsonr['min_price']
    max_price = jsonr['max_price'].blank? ? 1_000_000 : jsonr['max_price']
    joins = 'INNER JOIN categories_products ON products.id = categories_products.product_id'
    joins += ' INNER JOIN product_complects ON products.id = product_complects.product_id'
    whereprice = 'price >= ? AND price <= ?'
    products =
      if jsonr['tags'].blank? || jsonr['tags'].empty?
        Product.joins(joins).where('categories_products.category_id' => categories).where(whereprice, min_price, max_price)
      else
        Product.joins(joins + ' INNER JOIN products_tags ON products.id = products_tags.product_id').where('categories_products.category_id' => categories).where('products_tags.tag_id' => jsonr['tags']).where(whereprice, min_price, max_price)
      end
    @items = products.order(:orderp).uniq
    unless jsonr['sort_by'].blank?
      @items =
        if jsonr['sort_by'] == 'price-desc'
          @items.sort_by(&:price).reverse
        elsif jsonr['sort_by'] == 'price-asc'
          @items.sort_by(&:price)
        else
          @items.sort_by(&:title)
        end
    end
    @items = @items.drop(limit * page).take(limit)
    render 'category/withfilters', layout: false
  end

  get ('/testing') do
    regions = Subdomain.pluck(:subdomain_pool_id).uniq
    return regions.to_json
    a = []
    for reg in regions
      cities = Subdomain.where(subdomain_pool_id: reg).pluck(:url)
      h = Hash.new{|hsh,key| hsh[key] = [] }
      h[reg].push cities
      a.push(h)
    end
    return a.to_json
  end

  post 'category.json' do
    # puts "post category.json do api.rb"
    js = JSON.parse(request.body.read)
    p ["API PARAMS", js]
    content_type :json
    categories = Category.where(:parent_id => js["id"]).select("id").map {|c| c.id}
    joins = "INNER JOIN categories_products ON products.id = categories_products.product_id"
    price = [0, 10000000]
    price = js["price"] if not js["price"].blank?
    if js["tags"].blank?
      products = Product.joins(joins).where('categories_products.category_id' => categories).where("price >= ? AND price <= ?", price[0], price[1])
    else
      joins += " INNER JOIN products_tags ON products.id = products_tags.product_id"
      products = Product.joins(joins).where('categories_products.category_id' => categories).where("price >= ? AND price <= ?", price[0], price[1]).where('products_tags.tag_id' => js["tags"])
    end
    products.uniq.to_json
  end

  get 'cities2.json' do
    # puts "get 'cities2.json' do api.rb"
    content_type :json
    cities2 = Subdomain.select("id, city as name, suffix, price, free_delivery, freedelivery_summ")
    return cities2.to_json
  end

  get 'streets.json' do
    # puts "get 'streets.json' do api.rb"
    content_type :json
    streets = Murmanskstreet.all
    return streets.to_json
  end

  get "discounts.json" do
    # puts "get discounts.json do api.rb"
    content_type :json
    return '['+@subdsc.to_json+']'
  end

  get 'overtime.json' do
    # puts "get 'overtime.json' do api.rb"
    content_type :json
    overtime_deliveries = Subdomain.find(params[:id]).overtime_deliveries
    return overtime_deliveries.to_json({
      :methods => [:start_time_short, :end_time_short]
    })
  end

  #post 'product' do
  #  puts "post product do api.rb"
#
  #  content_type :json
  #  product = Product.find_by_id(params[:id])
  #  discount_data = product.get_local_discount(@subdomain, @subdomain_pool, product.categories)
  #
  #  product._complects = product.product_complects.map do |complect|
  #    {
  #      title: complect.complect.title,
  #      header: complect.complect.header,
  #      # price: complect.price * ((100.0 - discount_data.discount_in_percents) / 100) + discount_data.discount_in_rubles,
  #      price: product.get_local_complect_price(complect.id, @subdomain, @subdomain_pool, product.categories.first),
  #      image: complect.image,
  #      id: complect.complect_id
  #    }
  #  end
#
  #  product._tags = product.tag_complects.map do |tag|
  #    {
  #      title: tag.tag.title,
  #      count: tag.count,
  #      complect: tag.complect.title
  #    }
  #  end
#
  #  product.first_category_id = product.categories.first.id
#
  #  product.promotions = Category.find(product.first_category_id).products.limit(10).map { |x| x.to_json(methods: [:image, :price]) }
#
  #  product.to_json(:methods => [:image, :_complects, :_tags, :first_category_id, :promotions])
#
  #end


  get ('/product/:id/?') do
    # puts "get /product/:id/? do API.RB"

    if request.session[:mdata].nil?
      current_date = Date.current
      session[:mdata] = Date.current
    else
      current_date = request.session[:mdata]
      session[:mdata] = request.session[:mdata]
    end
    date_begin = Date.new(2019,3,23).to_s
    date_end = Date.new(2019,3,25).to_s
    value = ''
    $value1 = ''
    if current_date.to_s >= date_begin and current_date.to_s <= date_end
      $value1 = 'true'
      value = 'true'
      Product.check2($value1)
      ProductComplect.check(value)
    else
      $value1 = 'false'
      value = 'false'
      Product.check2($value1)
      ProductComplect.check(value)
    end

    #session_mdata = session[:mdata]
    content_type :json
    product1 = Product.find_by_id(params[:id])
    discount_data = product1.get_local_discount(@subdomain, @subdomain_pool, product1.categories)

    product1._complects = product1.product_complects.map do |complect|
      {
        title: complect.complect.title,
        header: complect.complect.header,
        # price: complect.price * ((100.0 - discount_data.discount_in_percents) / 100) + discount_data.discount_in_rubles,
        price: product1.get_local_complect_price(product1, @subdomain, @subdomain_pool, product1.categories.first),
        image: complect.image,
        id: complect.complect_id
      }
    end

    product1._tags = product1.tag_complects.map do |tag|
      {
        title: tag.tag.title,
        count: tag.count,
        complect: tag.complect.title
      }
    end

    product1.first_category_id = product1.categories.first.id
    product1.promotions = Category.find(product1.first_category_id).products.limit(10).map { |x| x.to_json(methods: [:image, :price]) }
    return product1.to_json(:methods => [:image, :_complects, :_tags, :first_category_id, :promotions])
  end

  post 'newproduct.json' do
    # puts "post newproduct.json do api.rb"
    if request.session[:mdata].nil?
      current_date = Date.current
      session[:mdata] = Date.current
    else
      current_date = request.session[:mdata]
      session[:mdata] = request.session[:mdata]
    end
    date_begin = Date.new(2019,3,23).to_s
    date_end = Date.new(2019,3,25).to_s
    value = ''
    $value1 = ''
    if current_date.to_s >= date_begin and current_date.to_s <= date_end
      $value1 = 'true'
      value = 'true'
      Product.check2($value1)
      ProductComplect.check(value)
    else
      $value1 = 'false'
      value = 'false'
      Product.check2($value1)
      ProductComplect.check(value)
    end

    js = JSON.parse(request.body.read)
    x_101 = [258, 978, 1145, 1183, 1208, 1244, 1255, 1580, 2204, 2230, 2282, 2335, 2367, 2445, 2447, 2499, 2500, 2501, 2553, 2568, 2581, 2585, 2725, 2728, 2746, 2834, 2835]
    special_array = [3045, 2853, 2854, 2853, 2853, 2852, 2846, 2988, 2846, 2849, 2855, 2661, 2988, 2662, 2849, 2661, 2849, 2846, 2988, 2661, 2660, 1934, 1934, 1934, 1934, 1937, 1935, 1936, 1845, 2988]
    # puts '!!!!!!!!!!!!!!!!!!!!!!!', @subdomain, '!!!!!!!!!!!!!!!!!!!!!!'

    content_type :json
    product = Product.find_by_id(js["id"])
    discount_data = product.get_local_discount(@subdomain, @subdomain_pool, product.categories)
    product._complects = product.product_complects.map do |complect|
      a = ProductComplect.where(id: complect['id'])[0]['product_id']
      if x_101.include?(a)
        # puts @subdomain
        extras = @subdomain['101roze']
      elsif special_array.include?(a)
        extras = @subdomain['ordprod']
      else
        extras = @subdomain['overprsubd']
      end

      {
        title: complect.complect.title,
        header: complect.complect.header,
        price: product.get_cmplct_price(complect.id, @subdomain.discount_pool_id, true) + extras,
        image: complect.image,
        id: complect.complect_id
      }

    end

    product._tags = product.tag_complects.map do |tag|
      {
        title: tag.tag.title,
        count: tag.count,
        complect: tag.complect.title
      }
    end
    # puts product.to_json
    product.first_category_id = product.categories.first.id
    product.promotions = Category.find(product.first_category_id).products.limit(10).map { |x| x.to_json(methods: [:image, :price]) }
    return product.to_json(:methods => [:image, :_complects, :_tags, :first_category_id, :promotions])
  end

  post 'newproduct2.json' do
    # puts "post newproduct2.json do api.rb"

    if cookies[:overcookie].nil?
      current_date = session[:mdata]
    else
      current_date = cookies[:overcookie]
    end
    date_begin = Date.new(2019,3,23).to_s
    date_end = Date.new(2019,3,25).to_s
    value = ''
    $value1 = ''
    # puts session[:mdata]
    # puts current_date
    if current_date.to_s >= date_begin and current_date.to_s <= date_end
      $value1 = 'true'
      value = 'true'
      Product.check2($value1)
      ProductComplect.check(value)
    else
      $value1 = 'false'
      value = 'false'
      Product.check2($value1)
      ProductComplect.check(value)
      #@change = ProductComplect.new()
      #@change.check(value)
    end

    js = JSON.parse(request.body.read)
    content_type :json
    product2 = Product.find_by_id(js["id"])
    discount_data = product2.get_local_discount(@subdomain, @subdomain_pool, product2.categories)

    product2._complects = product2.product_complects.map do |complect|
      {
        title: complect.complect.title,
        header: complect.complect.header,
        price: product2.get_cmplct_price(complect.id, @subdomain.discount_pool_id, true),
        image: complect.image,
        id: complect.complect_id
      }

    end

    product2._tags = product2.tag_complects.map do |tag|
      {
        title: tag.tag.title,
        count: tag.count,
        complect: tag.complect.title
      }
    end

    product2.first_category_id = product2.categories.first.id
    product2.promotions = Category.find(product2.first_category_id).products.limit(10).map { |x| x.to_json(methods: [:image, :price]) }
    return product2.to_json(:methods => [:image, :_complects, :_tags, :first_category_id, :promotions])
  end


  post 'cart.json' do
    # puts "post cart.json do API.RB"
      if cookies[:overcookie].nil?
        current_date = session[:mdata]
      else
        current_date = cookies[:overcookie]
      end
      date_begin = Date.new(2019,3,23).to_s
      date_end = Date.new(2019,3,25).to_s
      value = ''
      $value1 = ''
      if current_date.to_s >= date_begin and current_date.to_s <= date_end
        $value1 = 'true'
        value = 'true'
        Product.check2($value1)
        ProductComplect.check(value)
      else
        $value1 = 'false'
        value = 'false'
        Product.check2($value1)
        ProductComplect.check(value)
      end

    #session[:force] = 11
    session[:init] = true
    p session
    params = JSON.parse(request.body.read) || {}
    city_id = params['city_id']
    if city_id != @subdomain.id
      @subdomain = Subdomain.find(city_id)
      session[:subdomain] = @subdomain.id
      @subdomain_pool = SubdomainPool.find(@subdomain.subdomain_pool_id)
    end

    carts = session[:cart] || []
    products = []
    carts.each do |cart|
      product = Product.find(cart["id"])
      if product
          product.quantity = cart["quantity"]
          product.type = cart["type"]
          type_id = Complect.find_by_title(cart["type"]).id
          cmplct_id = ProductComplect.where(product_id: cart["id"], complect_id: type_id).order(created_at: :desc)[0].id
          product.discount_price = product.get_local_complect_price(cart, @subdomain, @subdomain_pool, product.categories)
          product.clean_price = product.get_local_complect_clean_price(cart, @subdomain, @subdomain_pool, product.categories)
         # product.discount_price = product.get_cmplct_price(cmplct_id, @subdomain.discount_pool_id, true)
         # product.clean_price = product.get_cmplct_price(cmplct_id, @subdomain.discount_pool_id, true)
          product.title = product_item2title(cart)
          products << product
      end
    end
    content_type :json
    products.to_json(:only => [:id, :title], :methods => [:quantity, :type, :discount_price, :clean_price])
  end

  post 'quantity.json' do
    # puts "post quantity.json do api.rb"
    js = JSON.parse(request.body.read)
    cart = session[:cart]
    cart.each_with_index do |item, index|
      if item["id"] == js["id"].to_s && (item["type"] == js["type"] || (item["type"].blank? && js["type"] == "standard" ))
        if js["method"] == "plus"
          cart[index]["quantity"] = (cart[index]["quantity"].to_i + 1).to_s
        elsif cart[index]["quantity"].to_i > 1
          cart[index]["quantity"] = (cart[index]["quantity"].to_i - 1).to_s
        end
      end
    end
    p ["QUANTITY", js]
    products = []
    content_type :json
    products.to_json
  end

  get 'default_category.json' do # для категории по умолчанию на гл.стр. поддомена (со слов бывалых)
    # puts "get default_category.json do api.rb"
    if @subdomain.enable_categories
      id = @subdomain.default_category_id
    elsif @subdomain_pool.enable_categories
      id = @subdomain_pool.default_category_id
    else
      id = 55
    end

      if request.session[:mdata].nil?
        current_date = Date.current
        session[:mdata] = Date.current
      else
        current_date = request.session[:mdata]
        session[:mdata] = request.session[:mdata]
      end
      date_begin = Date.new(2019,3,23).to_s
      date_end = Date.new(2019,3,25).to_s
      value = ''
      if current_date.to_s >= date_begin and current_date.to_s <= date_end
        value = 'true'
        ProductComplect.check(value)
      else
        value = 'false'
        ProductComplect.check(value)
        #@change = ProductComplect.new()
        #@change.check(value)
      end


    content_type :json
    {id: id}.to_json
  end

  post ('/subscribe/?') do
    # puts "post /subscribe/? do api.rb"
    @sbscrbr = Subscribers.create(
      name: params[:name],
      email: params[:email]
    )
    if @sbscrbr.save
      # erb 'Вы успешно подписались на нашу рассылку!' # redirect to '/'
      erb :'subscr/success' # redirect to '/'
    else
      erb 'Ошибка! Подписка не произведена' # redirect to '/'
    end
  end

  get ('/product-availability/:id/?') do
    # puts "get /product-availability/:id/? do api.rb"
    begin; erb Product.find(params[:id]).check_availability(@subdomain_pool).to_s
    rescue Exception => err; erb err.to_s; end
  end

  get ('/1c_exchange') do
    # puts "get /1c_exchange do api.rb"
    case params[:mode]
      when 'checkauth' then return 'success'
      when 'init' then return 'zip=no file_limit=1024000'
      when 'query'
        content_type 'text/xml'
        '<?xml version=\"2.0\" encoding=\"UTF-8\"?>'
        ord = Order.find_by_sql("SELECT * FROM orders INNER JOIN order_products ON orders.id = order_products.order_id WHERE erp_status = 0")
        # puts ord.to_xml
        doc = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
        xml.КоммерческаяИнформация("xmlns"=> "urn:1C.ru:commerceml_2", "ВерсияСхемы"=> "2.03", "xmlns:xs"=>"http://www.w3.org/2001/XMLSchema", "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance") {
          Order.find_by_sql("SELECT * FROM orders WHERE erp_status = 0 AND oname != '#{ENV['TESTER_NAME'].to_s}'").map { |x| xml.Документ {
            #if x.region != true
            #  puts "Hello"
            #  x.region = ' '
            #end
            if x.del_address != ''
              x.district_text = x.del_address
            else
              x.district_text = x.district_text
            end

            if x.d2_date == nil
              x.d2_date = x.d1_date
            end

            xml.Ид x.eight_digit_id ? x.eight_digit_id : x.id
            xml.Номер x.eight_digit_id
            xml.ПометкаУдаления 'false'
            xml.Дата x.created_at
            xml.ХозОперация 'Заказ товара'
            xml.Роль 'Продавец'
            xml.Валюта 'руб'
            xml.ИмяПолучателя x.dname
            xml.ТелефонПолучателя x.dtel
            xml.ВремяНачала x.date_from
            xml.ВремяОкончания x.date_to
            xml.ПозвонитьПолучателю x.dcall
            xml.КакОплатить x.payment_typetext
            xml.ОставитьСоседямБукет x.ostav
            xml.ФотоВручения x.make_photo
            xml.ГородДоставки x.city
            xml.Доставка x.dt_txt
            xml.НеГоворитьЧтоЦветы x.surprise
            xml.Оплата x.payment_typetext
            xml.ДатаДоставки x.d2_date
            #xml.Представление
            xml.ТекстОткрытки x.cart
            xml.ЦенаДоставки x.delivery_price
            xml.Комментарий x.comment
            xml.Сумма x.total_summ.to_i
            xml.Контрагенты {
              xml.Контрагент {
                xml.Ид x.eight_digit_id ? x.eight_digit_id : x.id
                xml.Наименование x.oname
                xml.Контакты {
                  xml.Контакт {
                    xml.Тип 'Электронная почта'
                    xml.Значение x.email
                  }
                  xml.Контакт {
                    xml.Тип 'Телефон Рабочий'
                    xml.Значение x.otel
                  }
                }
                xml.Роль 'Покупатель'
                xml.ОфициальноеНаименование 'Сайт'
                xml.АдресДоставки{
                  xml.Представление ', 184355, ' + x.region.to_s + ', , ' + x.city.to_s + ' г , , '  + x.district_text.to_s + ', ' + x.deldom.to_s + ', ' + x.delkorpus.to_s + ', ' + x.delkvart.to_s + ',,,'
                  xml.АдресноеПоле{
                    xml.Тип 'Почтовый индекс'
                    xml.Значение '184355'
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Страна'
                    xml.Значение x.country
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Город'
                    xml.Значение x.city
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Регион'
                    xml.Значение x.region
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Улица'
                    xml.Значение x.district_text
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Дом'
                    xml.Значение x.deldom
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Корпус'
                    xml.Значение x.delkorpus
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Квартира'
                    xml.Значение x.delkvart
                  }
                }
                xml.АдресРегистрации{
                  xml.Представление ', 184355, ' + x.region.to_s + ', , ' + x.city.to_s + ' г , , '  + x.district_text.to_s + ', ' + x.deldom.to_s + ', ' + x.delkorpus.to_s + ', ' + x.delkvart.to_s + ',,,'
                  xml.АдресноеПоле{
                    xml.Тип 'Почтовый индекс'
                    xml.Значение '184355'
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Страна'
                    xml.Значение x.country
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Город'
                    xml.Значение x.city
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Регион'
                    xml.Значение x.region
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Улица'
                    xml.Значение x.district_text
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Дом'
                    xml.Значение x.deldom
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Корпус'
                    xml.Значение x.delkorpus
                  }
                  xml.АдресноеПоле{
                    xml.Тип 'Квартира'
                    xml.Значение x.delkvart
                  }
                }
              }
            }

            xml.Товары {
              # if x.del_price == (nil || '0')
              #   next
              # else
                xml.Товар {
                  xml.Ид '00000001'
                  xml.Наименование 'Доставка'

                  xml.ЗначенияРеквизитов {
                    xml.ЗначениеРеквизита{
                      xml.Наименование 'ВидНоменклатуры'
                      xml.Значение 'Набор'
                    }
                    xml.ЗначениеРеквизита{
                      xml.Наименование 'ТипНоменклатуры'
                      xml.Значение 'Набор'
                    }
                  }
                  xml.КомплектТовара 'Стандартная'
                  xml.БазоваяЕдиница 'компл'
                  xml.Количество '1'
                  xml.ЦенаЗаЕдиницу x.del_price
                  xml.Сумма x.del_price
                }
              # end
            Order_product.find_by_sql("SELECT *  FROM order_products WHERE order_id = " + x.id.to_s + "").each_with_index { |x|
              xml.Товар {
                xml.Ид x.product_id
                xml.Наименование x.title

                xml.ЗначенияРеквизитов {
                  xml.ЗначениеРеквизита{
                    xml.Наименование 'ВидНоменклатуры'
                    xml.Значение 'Набор'
                  }
                    xml.ЗначениеРеквизита{
                    xml.Наименование 'ТипНоменклатуры'
                    xml.Значение 'Набор'
                  }
                }
                xml.КомплектТовара x.typing
                xml.БазоваяЕдиница 'компл'
                xml.Количество x.quantity
                xml.ЦенаЗаЕдиницу x.price
                xml.Сумма x.price*x.quantity
              }
            }
          }
        } } }end
        erb doc.to_xml
      when 'success'
        Order.where(erp_status: 0).each { |x| x.erp_status = 1; x.save }
        return 'ok'
      end
  end

  get ('/smiles-for-product/:id/cndtn.json') do
    @cndtn = false
    @postsss = Smile.all
    @postsss.each do |smile|
      order = JSON.parse(smile.json_order)
      order.each do |prdct|
        @cndtn = true if prdct[1]['id'] == params[:id]
      end
    end
    content_type :json
    if @cndtn; erb '[{"res":"true"}]'
    else; erb '[{"res":"false"}]'; end
  end

  get :payment do
    erb "Text: #{params[:amount]} #{params[:desc]}"
    # redirect_to "https://www.example.com"
  end

  # API endpoint для получения данных заказа по номеру (для автозаполнения в админке)
  get '/order_info/:order_id' do
    content_type :json
    
    begin
      order_id = params[:order_id].to_i
      
      # Проверяем формат номера заказа (должен быть 8-значным числом)
      if order_id < 10_000_000 || order_id > 99_999_999
        status 400
        return { error: 'Номер заказа должен быть 8-значным числом' }.to_json
      end
      
      # Ищем заказ по eight_digit_id
      order = Order.find_by_eight_digit_id(order_id)
      
      if order.nil?
        status 404
        return { error: 'Заказ с данным номером не найден' }.to_json
      end
      
      # Возвращаем только безопасную информацию о заказе
      order_data = {
        order_id: order.eight_digit_id,
        customer_name: order.oname || '',
        order_date: order.created_at.strftime('%d.%m.%Y'),
        city: order.city || '',
        status: 'найден'
      }
      
      return order_data.to_json
      
    rescue => e
      status 500
      return { error: 'Внутренняя ошибка сервера' }.to_json
    end
  end

end

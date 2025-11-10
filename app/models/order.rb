# encoding: utf-8
class Order < ActiveRecord::Base
	self.table_name = 'orders'  # Явно указываем имя таблицы
	self.primary_key = 'id'  # Явно указываем первичный ключ
	belongs_to :useraccount, class_name: 'UserAccount'
	belongs_to :status, class_name: 'Status'
	has_many :smiles, foreign_key: 'order_id'
	has_many :order_products, foreign_key: 'order_id', class_name: 'Order_product', dependent: :destroy
	
	# Связь с комментариями через eight_digit_id
	has_many :comments, :foreign_key => :order_eight_digit_id, :primary_key => :eight_digit_id

	def parse_price(key)
		i = 0
		str = ''
		# Безопасная загрузка данных с проверкой на ошибки
		begin
			order_products = Order_product.where('order_id = ?', key.to_s)
			puts "[DEBUG] Найдено order_products для заказа #{key}: #{order_products.count} шт." if ENV['DEBUG']
			sum_data = order_products.to_json
		rescue => e
			puts "Error in parse_price method: #{e.message}"
			return '' # Возвращаем пустую строку при ошибке
		end
		parse_title = sum_data.scan(/title+\W+"([\u0410-\u042f\u0430-\u044f\u0401\u0451\s\d().]+)"/).to_a
		parse_price_data = sum_data.scan(/[^_]price+\W+([\d]+)/).to_a
		parse_quantity = sum_data.scan(/quantity+\W+([\d]+)/).to_a
		
		# Логирование для диагностики
		if ENV['DEBUG']
			puts "[DEBUG] Найдено товаров: #{parse_title.length}, цен: #{parse_price_data.length}, количеств: #{parse_quantity.length}"
			puts "[DEBUG] Titles: #{parse_title.inspect}"
			puts "[DEBUG] Prices: #{parse_price_data.inspect}"
		end
		deliveries_price = begin
			Order.find(key).del_price || 0
		rescue
			0
		end
		parse_array = parse_title.zip(parse_price_data, parse_quantity)
		length_array = parse_array.length
		
		# Проверяем, что есть данные для обработки
		if length_array == 0
			puts "[WARNING] Нет данных о order_products для заказа ID: #{key}"
			return "Ошибка: нет товаров в заказе"
		end
		
		lmi_del_name = "&LMI_SHOPPINGCART.ITEMS[#{length_array}].NAME=Доставка"
		lmi_del_quantity = "&LMI_SHOPPINGCART.ITEMS[#{length_array}].QTY=1"
		lmi_del_price = "&LMI_SHOPPINGCART.ITEMS[#{length_array}].PRICE=#{deliveries_price}"
		lmi_del_tax = "&LMI_SHOPPINGCART.ITEMS[#{length_array}].TAX=vat0"
		loop do
			pt = parse_title[i].to_s.delete('[').delete('"').delete('"').delete(']')
			# Добавляем защиту от nil
			pp = parse_price_data[i]&.join&.to_i || 0
			pq = parse_quantity[i]&.join&.to_i || 1
			lmi_name = "&LMI_SHOPPINGCART.ITEMS[#{i}].NAME=#{pt}"
			str.concat(lmi_name)
			lmi_quantity = "&LMI_SHOPPINGCART.ITEMS[#{i}].QTY=#{pq}"
			str.concat(lmi_quantity)
			lmi_price = "&LMI_SHOPPINGCART.ITEMS[#{i}].PRICE=#{pp}"
			str.concat(lmi_price)
			lmi_tax = "&LMI_SHOPPINGCART.ITEMS[#{i}].TAX=vat0"
			str.concat(lmi_tax).to_s
			i += 1
			break if i == length_array
		end
		str.concat(lmi_del_name).concat(lmi_del_quantity).concat(lmi_del_price).concat(lmi_del_tax)
	rescue => e
		# Общая обработка ошибок метода parse_price
		puts "Fatal error in parse_price method: #{e.message}"
		puts e.backtrace.join("\n") if e.backtrace
		return '' # Возвращаем пустую строку при ошибке
	end
end
# 🔗 Настройка интеграционных тестов

Интеграционные тесты требуют полного окружения с базой данных.

## 🛠️ Требования

### 1. MySQL сервер
```bash
# Ubuntu/Debian
sudo apt-get install mysql-server mysql-client

# Запустить MySQL
sudo systemctl start mysql
sudo systemctl enable mysql
```

### 2. Ruby зависимости
```bash
# Установка dev пакетов для Ruby
sudo apt-get install ruby-dev libmysqlclient-dev

# Установка gem'ов
gem install activerecord mysql2 --no-document
```

### 3. База данных
```sql
-- Подключитесь к MySQL
mysql -u root -p

-- Создайте тестовую БД
CREATE DATABASE admin_rozario_test;

-- Создайте пользователя (опционально)
CREATE USER 'test_user'@'localhost' IDENTIFIED BY 'test_password';
GRANT ALL PRIVILEGES ON admin_rozario_test.* TO 'test_user'@'localhost';
FLUSH PRIVILEGES;
```

### 4. Минимальная структура таблиц
Для полного тестирования нужны таблицы:
```sql
USE admin_rozario_test;

-- Минимальная структура для тестов
CREATE TABLE comments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255),
  body TEXT,
  rating FLOAT DEFAULT 5.0,
  published BIT(1) DEFAULT 1,
  order_eight_digit_id INT,
  created_at DATETIME,
  updated_at DATETIME
);

CREATE TABLE orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  eight_digit_id INT,
  email VARCHAR(255),
  created_at DATETIME,
  updated_at DATETIME
);

CREATE TABLE smiles (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255),
  body TEXT,
  rating INT DEFAULT 5,
  published BIT(1) DEFAULT 1,
  order_eight_digit_id INT,
  created_at DATETIME,
  updated_at DATETIME
);
```

## 🎨 Переменные окружения

Создайте файл `.env` в корне проекта:
```bash
# Настройки базы данных для интеграционных тестов
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=admin_rozario_test
DB_USER=test_user
DB_PASSWORD=test_password
```

Или экспортируйте переменные:
```bash
export DB_HOST=127.0.0.1
export DB_NAME=admin_rozario_test  
export DB_USER=test_user
export DB_PASSWORD=test_password
```

## 🚀 Запуск

### Проверка окружения
```bash
cd tests
ruby integration/test_basic_models.rb
```
Ожидаемый результат:
```
✅ Подключение к БД установлено
✅ Модель Comment загружена
✅ Таблица comments: 0 записей
```

### Запуск всех интеграционных тестов
```bash
cd tests
./run_integration_tests.sh
```

## 🔧 Решение проблем

### Ошибка: "cannot load such file -- active_record"
```bash
gem install activerecord --no-document
```

### Ошибка: "Failed to build gem native extension" (mysql2)
```bash
# Ubuntu/Debian
sudo apt-get install libmysqlclient-dev ruby-dev

# CentOS/RHEL
sudo yum install mysql-devel ruby-devel

# Затем
gem install mysql2 --no-document
```

### Ошибка: "Подключение к БД отклонено"
1. Проверьте запущен MySQL: `sudo systemctl status mysql`
2. Проверьте переменные окружения
3. Проверьте права пользователя

### Ошибка: "Таблица не существует"
Выполните SQL скрипт создания таблиц выше.

## 📄 Статус тестов

- ✅ `test_basic_models.rb` - проверка окружения
- 🔄 `test_comments_orders.rb` - связь комментариев/заказов
- 🔄 `test_bit_field_published.rb` - BIT поля
- ✅ `test_smile_published_functionality.rb` - проверка файлов

> 📝 **Примечание**: Для полноценного тестирования в production нужно также создать `/srv/gems/multi_captcha` гем.

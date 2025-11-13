# Исправление отображения символа рубля

## Проблема
На iPhone символ рубля через Font Awesome `<i class="fa fa-rub"></i>` периодически исчезал из-за нестабильности загрузки шрифтов или CSS.

## Решение
Замена всех использований Font Awesome иконки рубля на Unicode-символ `₽` с CSS-классом `.ruble-symbol`.

### Было:
```html
<i class="fa fa-rub" aria-hidden="true"></i>
```

### Стало:
```html
<span class="ruble-symbol">₽</span>
```

## Изменённые файлы

### 1. Карточки товаров
- **`/app/app/views/product/_cardplace.haml`** - основная карточка товара (2 места)
- **`/app/app/views/category/perekrestok.haml`** - каталог категории (2 места + CSS стили)

### 2. Корзина
- **`/app/app/views/cart/_show.html.erb`** - отображение товаров в корзине (2 места)
- **`/app/app/views/cart/deleteme/show.html.erb`** - старая версия корзины (2 места)
- **`/app/app/views/cart/mailorder.erb`** - оформление заказа (5 мест)

### 3. Лайоуты (добавлен CSS)
- **`/app/app/views/layouts/application.haml`**
- **`/app/app/views/layouts/catalog.haml`**
- **`/app/app/views/layouts/+/applicationpr.haml`**
- **`/app/app/views/layouts/+/catalogpr.haml`**
- **`/app/app/views/layouts/erbhf.erb`**

## Добавленные CSS стили

Во все layouts добавлен следующий CSS:

```css
.ruble-symbol {
  font-weight: normal;
  font-family: Arial, sans-serif;
  display: inline;
  font-style: normal;
}
```

### Обновлённые CSS стили в perekrestok.haml

**Было:**
```css
#wr .price .fa-rub { font-size: 18px; }
#wr .old-spice .fa-rub { font-size: 13px; }
```

**Стало:**
```css
#wr .price .ruble-symbol { font-size: 18px; }
#wr .old-spice .ruble-symbol { font-size: 13px; }
```

## Преимущества нового решения

1. **Надёжность**: Unicode-символ `₽` поддерживается всеми современными браузерами
2. **Стабильность**: Не зависит от загрузки Font Awesome
3. **Производительность**: Меньше нагрузка на CSS селекторы
4. **Кроссплатформенность**: Одинаково отображается на всех устройствах
5. **SEO**: Лучшая семантика - текст, а не иконка

## Обратная совместимость

Если потребуется вернуть Font Awesome иконки, можно использовать следующую команду:

```bash
# Вернуть Font Awesome (НЕ РЕКОМЕНДУЕТСЯ)
find /app/app/views -name "*.haml" -o -name "*.erb" | xargs sed -i 's/<span class="ruble-symbol">₽</span>/<i class="fa fa-rub" aria-hidden="true"><\/i>/g'
```

## Тестирование

### Проверка замены
Убедиться, что Font Awesome иконки рубля больше не используются:

```bash
grep -r "fa-rub\|fa fa-rub" /app/app/views/ | grep -v backup
# Должно вернуть пустой результат
```

### Проверка нового символа
Проверить, что новые символы были добавлены:

```bash
grep -r "ruble-symbol" /app/app/views/ | wc -l
# Должно показать количество заменённых мест
```

### Проверка в браузере
1. Открыть любую страницу с товарами
2. Проверить, что рядом с ценой отображается символ `₽`
3. Открыть DevTools и убедиться, что используется `<span class="ruble-symbol">₽</span>`
4. Проверить на мобильном устройстве (iOS/Android)

### Особое внимание к iPhone
- Проверить отображение в Safari
- Проверить при медленном соединении
- Проверить стабильность отображения при перезагрузках страницы

## Результат

Символ рубля теперь отображается стабильно на всех устройствах, включая iPhone, без зависимости от загрузки внешних ресурсов.

**Общее количество замен:** 14 использований Font Awesome иконок рубля заменено на Unicode-символ.

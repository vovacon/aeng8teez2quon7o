# Обновление логики itemReviewed в микроразметке Review

## Изменения в получении данных о товаре

### До изменений:
```erb
"itemReviewed": {
  "name": "<%=prdct ? prdct.header : cmplct_header%>",
  "image": "<%=prdct ? prdct.thumb_image(true) : '/images/default-product.jpg'%>"
}
```
- Использовались данные из `json_order`
- Могли быть неточности в названиях товаров

### После изменений:
```erb
"itemReviewed": {
  "name": "<%=@post.review_item_name || (prdct ? prdct.header : cmplct_header)%>",
  "image": "<%=@post.review_item_image || (prdct ? prdct.thumb_image(true) : '/images/default-product.jpg')%>"
}
```

## Новые методы в модели Smile

### 1. `review_order_product()`
Получает запись из `order_products` по `order_products_base_id`

### 2. `review_item_name()`
Получает название товара для itemReviewed:
1. **Приоритет 1**: `order_products.title` (точное название на момент заказа)
2. **Приоритет 2**: `products.header` (через `order_products.product_id`)
3. **Fallback**: используется старая логика

### 3. `review_item_image()`
Получает изображение товара для itemReviewed:
1. Находит `Product` по `order_products.product_id`
2. Использует `product.thumb_image(true)` (mobile версия)
3. **Fallback**: используется старая логика

## Цепочка связей для получения данных

```
smile.order_products_base_id → order_products.base_id
                             ↓
order_products.title → itemReviewed.name
order_products.product_id → products.id
                          ↓  
products.default_image → product_complects → itemReviewed.image
```

## Преимущества новой логики

✅ **Точные данные** - используются реальные записи из заказов  
✅ **Правильные названия** - title из order_products точнее чем из каталога  
✅ **Корректные изображения** - через product_complects и default_image  
✅ **Fallback** - сохранена совместимость со старой логикой

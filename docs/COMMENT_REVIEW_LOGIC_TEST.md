# Тестирование новой логики микроразметки Review для Smiles

## Как работает новая логика

### 1. Проверка связи с комментариями
```ruby
# В модели Smile добавлены методы:
def related_comment
  Comment.find_by_order_eight_digit_id(order_eight_digit_id) if order_eight_digit_id.present?
end

def has_review_comment?
  comment = related_comment
  comment && comment.body.present?
end
```

### 2. Условная микроразметка в шаблоне
```erb
<% if @post.has_review_comment? %>
<script type="application/ld+json">
{
  "@type": "Review",
  "reviewBody": "<%=comment.body%>",  # Текст из комментария
  "author": {"name": "<%=comment.name || @post.customer_name%>"}
}
</script>
<% end %>
```

## Связь данных

**Smile** → **Order** → **Comment**

1. `smiles.order_eight_digit_id` 
2. `orders.eight_digit_id` 
3. `comments.order_eight_digit_id`

## Результат

✅ **Микроразметка Review показывается только при наличии комментария**  
✅ **reviewBody берется из реального текста комментария**  
✅ **Имя автора берется из комментария (или fallback к customer_name)**  
✅ **Рейтинг берется из комментария (или fallback к smile.rating)**

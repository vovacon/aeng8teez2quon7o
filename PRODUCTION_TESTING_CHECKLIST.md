# 🚀 Production Testing Checklist for order_products Structure Changes

## ⚠️ **CRITICAL: Test in staging environment first!**

---

## 📋 **Pre-Deployment Checklist**

### 1. Database Migration Readiness
- [ ] Database backup created
- [ ] Migration script prepared and tested
- [ ] Rollback plan documented
- [ ] Index on `order_id` confirmed in schema
- [ ] Old indexes identified for cleanup

### 2. Application Code Verification  
- [ ] All unit tests pass (23 tests, 84 assertions)
- [ ] Integration tests pass (7 tests, 32 assertions)
- [ ] Functional API tests pass (all scenarios)
- [ ] No syntax errors in modified files
- [ ] Code review completed

---

## 🧪 **Staging Environment Tests**

### Phase 1: Basic Functionality
- [ ] **Order Creation Flow**
  - [ ] Add products to cart
  - [ ] Proceed to checkout
  - [ ] Fill customer details
  - [ ] Submit order successfully
  - [ ] Verify order_products records created with `order_id`

- [ ] **Order Viewing**
  - [ ] Admin can view order details
  - [ ] Products display correctly in order
  - [ ] Smile integration works (order_products_base_id)

### Phase 2: API Testing
- [ ] **POST /api/v1/orders/create**
  - [ ] Create test order via API
  - [ ] Verify response contains order_id and include_tax
  - [ ] Check order_products table has correct `order_id` values
  - [ ] Confirm no records with old `id` structure

- [ ] **POST /api/v1/carts/current_order**
  - [ ] Cart API returns correct product data
  - [ ] Price calculations work
  - [ ] Delivery price included

- [ ] **GET /admin/smiles/order_products/:order_id**
  - [ ] Admin API returns products for order
  - [ ] `base_id` field contains order_product.id (new PK)
  - [ ] No errors when linking smiles to order products

### Phase 3: Data Integrity
- [ ] **SQL Query Testing**
  ```sql
  -- These queries should return data:
  SELECT * FROM order_products WHERE order_id = [existing_order_id];
  SELECT o.eight_digit_id, COUNT(op.id) FROM orders o 
    LEFT JOIN order_products op ON o.id = op.order_id 
    GROUP BY o.id LIMIT 10;
  
  -- This query should return NO data (old structure):
  SELECT * FROM order_products WHERE id IN (SELECT id FROM orders);
  ```

- [ ] **Foreign Key Integrity**
  - [ ] All order_products.order_id reference valid orders.id
  - [ ] No orphaned order_products records
  - [ ] Primary key constraints working on order_products.id

### Phase 4: Performance Testing
- [ ] **Query Performance**
  - [ ] Order details page loads under 2 seconds
  - [ ] Admin order list loads quickly
  - [ ] No N+1 query issues
  - [ ] Index on order_id is being used (check EXPLAIN)

- [ ] **Load Testing**
  - [ ] Multiple simultaneous order creations
  - [ ] Admin interface responsive under load
  - [ ] No database deadlocks

---

## 🔍 **Production Deployment Tests**

### Immediate Post-Deploy (0-5 minutes)
- [ ] **Smoke Tests**
  - [ ] Homepage loads
  - [ ] Product pages load
  - [ ] Cart functionality works
  - [ ] Admin login works

- [ ] **Critical Path Test**
  - [ ] Complete one test order end-to-end
  - [ ] Verify order appears in admin
  - [ ] Check order_products table structure

### Short Term (5-30 minutes)
- [ ] **Error Monitoring**
  - [ ] Check application logs for errors
  - [ ] Monitor database slow query log
  - [ ] Verify no 500 errors in web server logs

- [ ] **Feature Testing**
  - [ ] Test different product types/complects
  - [ ] Test different payment methods
  - [ ] Test both delivery and pickup options
  - [ ] Verify email notifications work

### Medium Term (30 minutes - 2 hours)
- [ ] **Real User Testing**
  - [ ] Monitor real customer orders
  - [ ] Check customer support tickets
  - [ ] Verify admin operations work normally

- [ ] **Data Consistency**
  - [ ] Compare order counts before/after
  - [ ] Verify no data loss
  - [ ] Check reporting functions

---

## 🚨 **Rollback Criteria**

Rollback immediately if:
- [ ] Unable to create new orders
- [ ] Order data not saving correctly
- [ ] Admin interface not loading order details
- [ ] Database errors in logs
- [ ] Customer complaints about checkout process

---

## 🔧 **Rollback Procedure**

1. **Code Rollback**
   ```bash
   git checkout previous-commit
   # Deploy previous version
   ```

2. **Database Rollback** (if data was migrated)
   ```sql
   -- Restore order_products structure
   -- Run rollback migration
   ```

3. **Verification**
   - [ ] Old code works with restored data
   - [ ] All functionality restored
   - [ ] Customer notifications sent if needed

---

## 📊 **Success Metrics**

### Technical Metrics
- [ ] 0% error rate on order creation
- [ ] Page load times under baseline
- [ ] Database query times improved
- [ ] All unit/integration tests pass

### Business Metrics  
- [ ] Order conversion rate maintained
- [ ] Customer satisfaction scores stable
- [ ] Admin productivity maintained
- [ ] No customer support escalations

---

## 📝 **Documentation Updates**

After successful deployment:
- [ ] Update API documentation
- [ ] Update database schema docs
- [ ] Document new query patterns
- [ ] Update troubleshooting guides

---

## ✅ **Sign-off**

- [ ] **Developer**: All code changes tested and verified
- [ ] **QA**: All test scenarios pass
- [ ] **DBA**: Database changes verified
- [ ] **DevOps**: Deployment process tested
- [ ] **Product**: Business requirements met

**Final approval**: _______________  **Date**: _______________

---

*💡 **Tip**: Keep this checklist handy during deployment and check off items as you complete them. Document any issues found and their resolutions.*
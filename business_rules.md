# Business rules and assumptions

1. Every order belongs to one branch.
2. An order may be associated with a customer; anonymous walk-in orders are allowed.
3. An order can contain one or more menu items.
4. Quantity must be a positive whole number.
5. Menu item price cannot be negative.
6. An order's line-item price is snapshotted when the order is created.
7. Discount cannot exceed the subtotal.
8. Total amount = subtotal - discount + tax + delivery fee.
9. Supported order types: DINE_IN, TAKEAWAY, DELIVERY.
10. Supported statuses: PLACED, CONFIRMED, PREPARING, READY, COMPLETED, CANCELLED.
11. Completed and cancelled orders are terminal in the supplied status procedure.
12. Payments must be positive and cannot exceed the outstanding balance through `usp_RecordPayment`.
13. Transaction references are unique when supplied.
14. Inventory cannot be reduced below zero through the inventory ledger trigger.
15. Sample tax rate and sample records are for demonstration only, not tax or accounting advice.

## Deliberate scope boundary

This version does not automatically deduct ingredient inventory when a menu item is ordered. A robust restaurant model should use `MenuItemRecipes(MenuItemID, InventoryItemID, QuantityRequired)` so one dish can consume multiple ingredients. That extension is described in the README and is a good next iteration for a portfolio.

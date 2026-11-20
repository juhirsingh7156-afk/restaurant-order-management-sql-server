# Data dictionary

| Table | Purpose | Primary key | Important relationships |
|---|---|---|---|
| Branches | Restaurant locations | BranchID | Parent of Employees, Orders, BranchInventory |
| Employees | Staff assigned to a branch | EmployeeID | BranchID -> Branches |
| Customers | Customer profiles | CustomerID | Parent of RestaurantOrders |
| Categories | Menu grouping | CategoryID | Parent of MenuItems |
| MenuItems | Sellable menu products | MenuItemID | CategoryID -> Categories |
| RestaurantOrders | Order header and financial totals | OrderID | Branch, Customer, Employee |
| OrderItems | Products and quantities per order | OrderItemID | OrderID, MenuItemID |
| Payments | Payment attempts/records | PaymentID | OrderID -> RestaurantOrders |
| InventoryItems | Stock keeping units | InventoryItemID | Parent of BranchInventory |
| BranchInventory | On-hand stock by branch | BranchID + InventoryItemID | Branches, InventoryItems |
| InventoryTransactions | Stock movement ledger | InventoryTransactionID | Branch, InventoryItem |
| OrderStatusHistory | Business status timeline | StatusHistoryID | OrderID |
| OrderAudit | Database status-change audit | AuditID | Stores OrderID as audit reference |

## Important columns

- `RestaurantOrders.TotalAmount`: final order amount including tax and delivery fee, less discount.
- `OrderItems.UnitPrice`: price snapshot captured at sale time.
- `OrderItems.LineTotal`: persisted computed value of Quantity multiplied by UnitPrice.
- `Payments.TransactionRef`: optional unique external transaction identifier.
- `BranchInventory.QuantityOnHand`: current stock balance for the branch and stock item.
- `InventoryTransactions.QuantityChange`: signed stock movement; receipts positive, usage/waste negative.

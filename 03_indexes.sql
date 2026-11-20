USE RestaurantOrderManagement;
GO

CREATE INDEX IX_Orders_Branch_OrderDate
ON dbo.RestaurantOrders (BranchID, OrderDate)
INCLUDE (OrderStatus, TotalAmount, CustomerID);

CREATE INDEX IX_Orders_Customer_OrderDate
ON dbo.RestaurantOrders (CustomerID, OrderDate DESC)
INCLUDE (OrderStatus, TotalAmount);

CREATE INDEX IX_OrderItems_OrderID
ON dbo.OrderItems (OrderID)
INCLUDE (MenuItemID, Quantity, UnitPrice);

CREATE INDEX IX_Payments_Order_Status
ON dbo.Payments (OrderID, PaymentStatus)
INCLUDE (Amount, PaymentDate, PaymentMethod);

CREATE INDEX IX_MenuItems_Category_Available
ON dbo.MenuItems (CategoryID, IsAvailable)
INCLUDE (ItemName, UnitPrice);

CREATE INDEX IX_Inventory_Branch_Quantity
ON dbo.BranchInventory (BranchID, QuantityOnHand)
INCLUDE (InventoryItemID, LastUpdated);
GO

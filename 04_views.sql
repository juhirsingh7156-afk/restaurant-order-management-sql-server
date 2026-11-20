USE RestaurantOrderManagement;
GO

CREATE OR ALTER VIEW dbo.vw_OrderDetails
AS
SELECT
    o.OrderID, o.OrderDate, b.BranchName,
    CONCAT(c.FirstName, N' ', c.LastName) AS CustomerName,
    o.OrderType, o.OrderStatus,
    mi.ItemName, oi.Quantity, oi.UnitPrice, oi.LineTotal,
    o.Subtotal, o.DiscountAmount, o.TaxAmount, o.DeliveryFee, o.TotalAmount
FROM dbo.RestaurantOrders AS o
JOIN dbo.Branches AS b ON b.BranchID = o.BranchID
LEFT JOIN dbo.Customers AS c ON c.CustomerID = o.CustomerID
JOIN dbo.OrderItems AS oi ON oi.OrderID = o.OrderID
JOIN dbo.MenuItems AS mi ON mi.MenuItemID = oi.MenuItemID;
GO

CREATE OR ALTER VIEW dbo.vw_DailyBranchSales
AS
SELECT
    CAST(o.OrderDate AS DATE) AS SalesDate,
    b.BranchID, b.BranchName,
    COUNT_BIG(*) AS OrderCount,
    SUM(o.Subtotal) AS GrossItemSales,
    SUM(o.DiscountAmount) AS Discounts,
    SUM(o.TaxAmount) AS TaxCollected,
    SUM(o.DeliveryFee) AS DeliveryFees,
    SUM(o.TotalAmount) AS NetSales
FROM dbo.RestaurantOrders AS o
JOIN dbo.Branches AS b ON b.BranchID = o.BranchID
WHERE o.OrderStatus <> 'CANCELLED'
GROUP BY CAST(o.OrderDate AS DATE), b.BranchID, b.BranchName;
GO

CREATE OR ALTER VIEW dbo.vw_InventoryReorderAlerts
AS
SELECT
    b.BranchName, i.InventoryItemID, i.ItemName,
    bi.QuantityOnHand, i.ReorderLevel, i.UnitOfMeasure
FROM dbo.BranchInventory AS bi
JOIN dbo.Branches AS b ON b.BranchID = bi.BranchID
JOIN dbo.InventoryItems AS i ON i.InventoryItemID = bi.InventoryItemID
WHERE bi.QuantityOnHand <= i.ReorderLevel;
GO

CREATE OR ALTER VIEW dbo.vw_CustomerLifetimeValue
AS
SELECT
    c.CustomerID,
    CONCAT(c.FirstName, N' ', c.LastName) AS CustomerName,
    COUNT(o.OrderID) AS CompletedOrderCount,
    COALESCE(SUM(o.TotalAmount), 0) AS LifetimeSpend,
    MAX(o.OrderDate) AS LastOrderDate
FROM dbo.Customers AS c
LEFT JOIN dbo.RestaurantOrders AS o
    ON o.CustomerID = c.CustomerID AND o.OrderStatus = 'COMPLETED'
GROUP BY c.CustomerID, c.FirstName, c.LastName;
GO

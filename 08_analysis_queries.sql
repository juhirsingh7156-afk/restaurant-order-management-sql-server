USE RestaurantOrderManagement;
GO

/* 1. Overall revenue and completed order count */
SELECT
    COUNT(*) AS CompletedOrders,
    SUM(TotalAmount) AS TotalRevenue,
    AVG(TotalAmount) AS AverageOrderValue
FROM dbo.RestaurantOrders
WHERE OrderStatus = 'COMPLETED';
GO

/* 2. Top 10 menu items by quantity sold and revenue */
SELECT TOP (10)
    m.MenuItemID, m.ItemName,
    SUM(oi.Quantity) AS UnitsSold,
    SUM(oi.LineTotal) AS Revenue
FROM dbo.OrderItems oi
JOIN dbo.RestaurantOrders o ON o.OrderID = oi.OrderID
JOIN dbo.MenuItems m ON m.MenuItemID = oi.MenuItemID
WHERE o.OrderStatus = 'COMPLETED'
GROUP BY m.MenuItemID, m.ItemName
ORDER BY Revenue DESC;
GO

/* 3. Top 10 customers by lifetime spend */
SELECT TOP (10) *
FROM dbo.vw_CustomerLifetimeValue
ORDER BY LifetimeSpend DESC;
GO

/* 4. Month-over-month revenue and growth using LAG */
WITH MonthlySales AS
(
    SELECT
        DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) AS SalesMonth,
        SUM(TotalAmount) AS Revenue
    FROM dbo.RestaurantOrders
    WHERE OrderStatus = 'COMPLETED'
    GROUP BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1)
),
WithPreviousMonth AS
(
    SELECT SalesMonth, Revenue,
           LAG(Revenue) OVER (ORDER BY SalesMonth) AS PreviousMonthRevenue
    FROM MonthlySales
)
SELECT SalesMonth, Revenue, PreviousMonthRevenue,
       CASE WHEN PreviousMonthRevenue IS NULL OR PreviousMonthRevenue = 0 THEN NULL
            ELSE CONVERT(DECIMAL(10,2),
                 (Revenue - PreviousMonthRevenue) * 100.0 / PreviousMonthRevenue)
       END AS MoM_Growth_Percent
FROM WithPreviousMonth
ORDER BY SalesMonth;
GO

/* 5. Branch ranking by revenue */
WITH BranchRevenue AS
(
    SELECT b.BranchID, b.BranchName, SUM(o.TotalAmount) AS Revenue
    FROM dbo.Branches b
    LEFT JOIN dbo.RestaurantOrders o
      ON o.BranchID = b.BranchID AND o.OrderStatus = 'COMPLETED'
    GROUP BY b.BranchID, b.BranchName
)
SELECT BranchID, BranchName, COALESCE(Revenue,0) AS Revenue,
       DENSE_RANK() OVER (ORDER BY COALESCE(Revenue,0) DESC) AS RevenueRank
FROM BranchRevenue;
GO

/* 6. Category revenue contribution */
SELECT c.CategoryName,
       SUM(oi.LineTotal) AS CategoryRevenue,
       CONVERT(DECIMAL(6,2),
         100.0 * SUM(oi.LineTotal) /
         NULLIF(SUM(SUM(oi.LineTotal)) OVER (), 0)) AS RevenueSharePercent
FROM dbo.OrderItems oi
JOIN dbo.RestaurantOrders o ON o.OrderID = oi.OrderID
JOIN dbo.MenuItems m ON m.MenuItemID = oi.MenuItemID
JOIN dbo.Categories c ON c.CategoryID = m.CategoryID
WHERE o.OrderStatus = 'COMPLETED'
GROUP BY c.CategoryName
ORDER BY CategoryRevenue DESC;
GO

/* 7. Payment method popularity */
SELECT PaymentMethod, COUNT(*) AS PaymentCount, SUM(Amount) AS AmountCollected
FROM dbo.Payments
WHERE PaymentStatus = 'SUCCESS'
GROUP BY PaymentMethod
ORDER BY PaymentCount DESC;
GO

/* 8. Cancellation rate */
SELECT
    COUNT(*) AS TotalOrders,
    SUM(CASE WHEN OrderStatus = 'CANCELLED' THEN 1 ELSE 0 END) AS CancelledOrders,
    CONVERT(DECIMAL(6,2),
      100.0 * SUM(CASE WHEN OrderStatus = 'CANCELLED' THEN 1 ELSE 0 END)
      / NULLIF(COUNT(*),0)) AS CancellationRatePercent
FROM dbo.RestaurantOrders;
GO

/* 9. Customers who have not ordered in the last 90 days */
SELECT c.CustomerID, c.FirstName, c.LastName, MAX(o.OrderDate) AS LastOrderDate
FROM dbo.Customers c
LEFT JOIN dbo.RestaurantOrders o
  ON o.CustomerID = c.CustomerID AND o.OrderStatus <> 'CANCELLED'
GROUP BY c.CustomerID, c.FirstName, c.LastName
HAVING MAX(o.OrderDate) IS NULL
    OR MAX(o.OrderDate) < DATEADD(DAY, -90, SYSDATETIME());
GO

/* 10. Peak ordering hour */
SELECT DATEPART(HOUR, OrderDate) AS OrderHour,
       COUNT(*) AS OrderCount
FROM dbo.RestaurantOrders
WHERE OrderStatus <> 'CANCELLED'
GROUP BY DATEPART(HOUR, OrderDate)
ORDER BY OrderCount DESC;
GO

/* 11. Orders with outstanding payment balance */
SELECT o.OrderID, o.TotalAmount,
       COALESCE(SUM(CASE WHEN p.PaymentStatus = 'SUCCESS' THEN p.Amount ELSE 0 END),0) AS PaidAmount,
       o.TotalAmount - COALESCE(SUM(CASE WHEN p.PaymentStatus = 'SUCCESS' THEN p.Amount ELSE 0 END),0) AS Balance
FROM dbo.RestaurantOrders o
LEFT JOIN dbo.Payments p ON p.OrderID = o.OrderID
GROUP BY o.OrderID, o.TotalAmount
HAVING o.TotalAmount - COALESCE(SUM(CASE WHEN p.PaymentStatus = 'SUCCESS' THEN p.Amount ELSE 0 END),0) > 0;
GO

/* 12. Inventory items requiring reorder */
SELECT * FROM dbo.vw_InventoryReorderAlerts
ORDER BY BranchName, ItemName;
GO

/* 13. CTE: customer order sequence */
WITH CustomerOrderSequence AS
(
    SELECT CustomerID, OrderID, OrderDate, TotalAmount,
           ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS OrderSequence
    FROM dbo.RestaurantOrders
    WHERE CustomerID IS NOT NULL
)
SELECT * FROM CustomerOrderSequence
ORDER BY CustomerID, OrderSequence;
GO

/* 14. Self-join example: compare employees in the same branch */
SELECT e1.BranchID,
       CONCAT(e1.FirstName, ' ', e1.LastName) AS EmployeeOne,
       CONCAT(e2.FirstName, ' ', e2.LastName) AS EmployeeTwo
FROM dbo.Employees e1
JOIN dbo.Employees e2
  ON e1.BranchID = e2.BranchID AND e1.EmployeeID < e2.EmployeeID;
GO

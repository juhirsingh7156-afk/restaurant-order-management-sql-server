/*
  PERFORMANCE DEMO: branch sales by date range.
  Run after 10_synthetic_dataset.sql. Capture Actual Execution Plan (Ctrl+M in SSMS)
  and STATISTICS IO/TIME output for the BEFORE and AFTER SELECT statements.

  The normal project index IX_Orders_Branch_OrderDate is temporarily removed so the
  BEFORE query has no matching branch/date index. It is restored at the end.
*/
USE RestaurantOrderManagement;
GO
SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.RestaurantOrders') AND name='IX_Demo_Branch_Date_Cover')
    DROP INDEX IX_Demo_Branch_Date_Cover ON dbo.RestaurantOrders;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.RestaurantOrders') AND name='IX_Orders_Branch_OrderDate')
    DROP INDEX IX_Orders_Branch_OrderDate ON dbo.RestaurantOrders;
GO
-- BEFORE: with the project's branch/date index temporarily removed.
SELECT BranchID, CONVERT(date, OrderDate) AS SalesDate,
       COUNT_BIG(*) AS OrderCount, SUM(TotalAmount) AS Revenue
FROM dbo.RestaurantOrders
WHERE BranchID = (SELECT MIN(BranchID) FROM dbo.Branches)
  AND OrderDate >= DATEADD(DAY,-90,SYSDATETIME())
  AND OrderDate < SYSDATETIME()
GROUP BY BranchID, CONVERT(date, OrderDate)
ORDER BY SalesDate;
GO
-- AFTER: add a covering nonclustered index for equality + date-range filtering.
CREATE INDEX IX_Demo_Branch_Date_Cover
ON dbo.RestaurantOrders(BranchID, OrderDate)
INCLUDE (TotalAmount);
GO
SELECT BranchID, CONVERT(date, OrderDate) AS SalesDate,
       COUNT_BIG(*) AS OrderCount, SUM(TotalAmount) AS Revenue
FROM dbo.RestaurantOrders
WHERE BranchID = (SELECT MIN(BranchID) FROM dbo.Branches)
  AND OrderDate >= DATEADD(DAY,-90,SYSDATETIME())
  AND OrderDate < SYSDATETIME()
GROUP BY BranchID, CONVERT(date, OrderDate)
ORDER BY SalesDate;
GO
-- Restore the project's original index definition and remove the demo-only index.
DROP INDEX IX_Demo_Branch_Date_Cover ON dbo.RestaurantOrders;
CREATE INDEX IX_Orders_Branch_OrderDate
ON dbo.RestaurantOrders (BranchID, OrderDate)
INCLUDE (OrderStatus, TotalAmount, CustomerID);
GO
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

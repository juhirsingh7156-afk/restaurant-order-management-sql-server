/*
  OPTIONAL LARGE SYNTHETIC DATASET
  Run after scripts 00-07 and after the small starter seed data (02_seed_data.sql).
  Creates 2,000 additional fictional orders and 4,000 order lines.
  All names, emails and phone numbers are fabricated; example.test is reserved for examples.
  Safe to run once on a fresh project database. Do not rerun without resetting the database.
*/
USE RestaurantOrderManagement;
GO
SET NOCOUNT ON;

IF (SELECT COUNT(*) FROM dbo.RestaurantOrders) > 20
    THROW 50100, 'Synthetic loader expects a fresh database with only the starter seed data. Reset the database before rerunning.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.Branches) OR NOT EXISTS (SELECT 1 FROM dbo.Customers)
   OR NOT EXISTS (SELECT 1 FROM dbo.MenuItems) OR NOT EXISTS (SELECT 1 FROM dbo.Employees)
    THROW 50101, 'Run the schema and starter seed scripts first.', 1;

;WITH N AS
(
    SELECT TOP (2000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
), BranchRows AS
(
    SELECT BranchID, ROW_NUMBER() OVER (ORDER BY BranchID) AS rn FROM dbo.Branches
), CustomerRows AS
(
    SELECT CustomerID, ROW_NUMBER() OVER (ORDER BY CustomerID) AS rn FROM dbo.Customers
), EmployeeRows AS
(
    SELECT EmployeeID, ROW_NUMBER() OVER (ORDER BY EmployeeID) AS rn FROM dbo.Employees
), MenuRows AS
(
    SELECT MenuItemID, ROW_NUMBER() OVER (ORDER BY MenuItemID) AS rn FROM dbo.MenuItems
), SourceRows AS
(
    SELECT n.n,
           b.BranchID, c.CustomerID, e.EmployeeID,
           m1.MenuItemID AS Menu1, m2.MenuItemID AS Menu2,
           1 + (n.n % 4) AS Qty1,
           1 + ((n.n * 7) % 3) AS Qty2,
           DATEADD(MINUTE, -((n.n * 37) % 120000), SYSDATETIME()) AS OrderDate
    FROM N n
    CROSS JOIN (SELECT COUNT(*) AS Cnt FROM BranchRows) bc
    CROSS JOIN (SELECT COUNT(*) AS Cnt FROM CustomerRows) cc
    CROSS JOIN (SELECT COUNT(*) AS Cnt FROM EmployeeRows) ec
    CROSS JOIN (SELECT COUNT(*) AS Cnt FROM MenuRows) mc
    JOIN BranchRows b ON b.rn = ((n.n - 1) % bc.Cnt) + 1
    JOIN CustomerRows c ON c.rn = ((n.n - 1) % cc.Cnt) + 1
    JOIN EmployeeRows e ON e.rn = ((n.n - 1) % ec.Cnt) + 1
    JOIN MenuRows m1 ON m1.rn = ((n.n - 1) % mc.Cnt) + 1
    JOIN MenuRows m2 ON m2.rn = (n.n % mc.Cnt) + 1
), Calculated AS
(
    SELECT s.*, CONVERT(DECIMAL(12,2), s.Qty1*mi1.UnitPrice + s.Qty2*mi2.UnitPrice) AS Subtotal
    FROM SourceRows s
    JOIN dbo.MenuItems mi1 ON mi1.MenuItemID=s.Menu1
    JOIN dbo.MenuItems mi2 ON mi2.MenuItemID=s.Menu2
)
SELECT * INTO #SyntheticOrders FROM Calculated;

CREATE TABLE #OrderMap (SyntheticN INT NOT NULL PRIMARY KEY, OrderID BIGINT NOT NULL);

DECLARE @Inserted TABLE (OrderID BIGINT, Notes NVARCHAR(500));
INSERT dbo.RestaurantOrders
    (BranchID, CustomerID, EmployeeID, OrderDate, OrderType, OrderStatus,
     Subtotal, DiscountAmount, TaxAmount, DeliveryFee, TotalAmount, Notes)
OUTPUT inserted.OrderID, inserted.Notes INTO @Inserted(OrderID, Notes)
SELECT BranchID, CustomerID, EmployeeID, OrderDate,
       CASE n % 3 WHEN 0 THEN 'DINE_IN' WHEN 1 THEN 'TAKEAWAY' ELSE 'DELIVERY' END,
       CASE n % 5 WHEN 0 THEN 'COMPLETED' WHEN 1 THEN 'READY' WHEN 2 THEN 'PREPARING' ELSE 'PLACED' END,
       Subtotal, 0, CONVERT(DECIMAL(12,2), Subtotal * 0.05),
       CASE WHEN n % 3 = 2 THEN 30.00 ELSE 0 END,
       CONVERT(DECIMAL(12,2), Subtotal * 1.05 + CASE WHEN n % 3 = 2 THEN 30.00 ELSE 0 END),
       CONCAT('SYNTHETIC DEMO ORDER #', n)
FROM #SyntheticOrders;

INSERT #OrderMap(SyntheticN, OrderID)
SELECT TRY_CONVERT(INT, RIGHT(Notes, LEN(Notes) - CHARINDEX('#', Notes))), OrderID
FROM @Inserted;

INSERT dbo.OrderItems (OrderID, MenuItemID, Quantity, UnitPrice, SpecialInstructions)
SELECT m.OrderID, s.Menu1, s.Qty1, mi.UnitPrice, 'Synthetic dataset line item'
FROM #SyntheticOrders s JOIN #OrderMap m ON m.SyntheticN=s.n
JOIN dbo.MenuItems mi ON mi.MenuItemID=s.Menu1
UNION ALL
SELECT m.OrderID, s.Menu2, s.Qty2, mi.UnitPrice, 'Synthetic dataset line item'
FROM #SyntheticOrders s JOIN #OrderMap m ON m.SyntheticN=s.n
JOIN dbo.MenuItems mi ON mi.MenuItemID=s.Menu2;

INSERT dbo.OrderStatusHistory(OrderID, OldStatus, NewStatus, ChangedAt)
SELECT OrderID, NULL, 'PLACED', OrderDate FROM dbo.RestaurantOrders
WHERE Notes LIKE 'SYNTHETIC DEMO ORDER #%';

INSERT dbo.OrderStatusHistory(OrderID, OldStatus, NewStatus, ChangedAt)
SELECT OrderID, 'PLACED', OrderStatus, DATEADD(MINUTE, 2, OrderDate)
FROM dbo.RestaurantOrders
WHERE Notes LIKE 'SYNTHETIC DEMO ORDER #%'
  AND OrderStatus <> 'PLACED';

INSERT dbo.Payments(OrderID, PaymentDate, PaymentMethod, PaymentStatus, Amount, TransactionRef)
SELECT o.OrderID, o.OrderDate, CASE o.OrderID % 3 WHEN 0 THEN 'CASH' WHEN 1 THEN 'CARD' ELSE 'UPI' END,
       'SUCCESS', o.TotalAmount, CONCAT('SYNTH-', o.OrderID)
FROM dbo.RestaurantOrders o
WHERE o.Notes LIKE 'SYNTHETIC DEMO ORDER #%'
  AND o.OrderStatus='COMPLETED';

SELECT 'Synthetic dataset loaded' AS Result,
       COUNT(*) AS SyntheticOrders
FROM dbo.RestaurantOrders WHERE Notes LIKE 'SYNTHETIC DEMO ORDER #%';
GO

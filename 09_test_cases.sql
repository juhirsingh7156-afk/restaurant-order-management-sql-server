USE RestaurantOrderManagement;
GO

/* TEST 1: Basic row counts */
SELECT 'Branches' AS EntityName, COUNT(*) AS RowCount FROM dbo.Branches
UNION ALL SELECT 'Customers', COUNT(*) FROM dbo.Customers
UNION ALL SELECT 'MenuItems', COUNT(*) FROM dbo.MenuItems
UNION ALL SELECT 'Orders', COUNT(*) FROM dbo.RestaurantOrders
UNION ALL SELECT 'OrderItems', COUNT(*) FROM dbo.OrderItems;
GO

/* TEST 2: Check that every order line has a valid parent order */
SELECT oi.*
FROM dbo.OrderItems oi
LEFT JOIN dbo.RestaurantOrders o ON o.OrderID = oi.OrderID
WHERE o.OrderID IS NULL;
-- Expected: zero rows.
GO

/* TEST 3: Validate stored procedure order placement */
DECLARE @CreatedOrderID BIGINT;
EXEC dbo.usp_PlaceOrder
    @BranchID = 1,
    @CustomerID = 1,
    @EmployeeID = 2,
    @OrderType = 'TAKEAWAY',
    @ItemsJson = N'[{"MenuItemID":1,"Quantity":2},{"MenuItemID":6,"Quantity":1}]',
    @DiscountAmount = 10,
    @TaxRate = 0.05,
    @DeliveryFee = 0,
    @Notes = N'Automated test order',
    @NewOrderID = @CreatedOrderID OUTPUT;

SELECT @CreatedOrderID AS CreatedOrderID;
SELECT * FROM dbo.vw_OrderDetails WHERE OrderID = @CreatedOrderID;
GO

/* TEST 4: Update status and verify history/audit */
DECLARE @TestOrderID BIGINT =
(
    SELECT TOP (1) OrderID
    FROM dbo.RestaurantOrders
    WHERE OrderStatus = 'PLACED'
    ORDER BY OrderID DESC
);
IF @TestOrderID IS NOT NULL
BEGIN
    EXEC dbo.usp_UpdateOrderStatus @OrderID = @TestOrderID, @NewStatus = 'CONFIRMED';
    SELECT * FROM dbo.OrderStatusHistory WHERE OrderID = @TestOrderID ORDER BY ChangedAt;
    SELECT * FROM dbo.OrderAudit WHERE OrderID = @TestOrderID ORDER BY ChangedAt;
END;
GO

/* TEST 5: Inventory receipt and ledger application */
EXEC dbo.usp_AddInventory
    @BranchID = 1,
    @InventoryItemID = 1,
    @Quantity = 2.500,
    @ReferenceText = N'Test stock receipt';

SELECT * FROM dbo.BranchInventory WHERE BranchID = 1 AND InventoryItemID = 1;
SELECT TOP (5) * FROM dbo.InventoryTransactions ORDER BY TransactionDate DESC;
GO

/* TEST 6: Payment balance function */
SELECT OrderID, TotalAmount, dbo.fn_OrderPaymentBalance(OrderID) AS OutstandingBalance
FROM dbo.RestaurantOrders
ORDER BY OrderID;
GO

/* TEST 7: Constraints - uncomment to confirm rejection of invalid data */
/*
INSERT dbo.OrderItems (OrderID, MenuItemID, Quantity, UnitPrice)
VALUES (1, 1, -1, 10); -- Expected: CHECK constraint error.

INSERT dbo.RestaurantOrders
(BranchID, OrderType, OrderStatus, Subtotal, DiscountAmount, TaxAmount, DeliveryFee, TotalAmount)
VALUES (1, 'INVALID', 'PLACED', 10, 0, 0, 0, 10); -- Expected: CHECK constraint error.
*/

USE RestaurantOrderManagement;
GO

/*
  JSON input example:
  [
    {"MenuItemID":1,"Quantity":2},
    {"MenuItemID":3,"Quantity":1}
  ]

  Tax rate is a demo parameter. Real tax rules should be configurable by jurisdiction.
*/
CREATE OR ALTER PROCEDURE dbo.usp_PlaceOrder
    @BranchID INT,
    @CustomerID INT = NULL,
    @EmployeeID INT = NULL,
    @OrderType VARCHAR(20),
    @ItemsJson NVARCHAR(MAX),
    @DiscountAmount DECIMAL(12,2) = 0,
    @TaxRate DECIMAL(6,4) = 0.05,
    @DeliveryFee DECIMAL(12,2) = 0,
    @Notes NVARCHAR(500) = NULL,
    @NewOrderID BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @OrderType NOT IN ('DINE_IN','TAKEAWAY','DELIVERY')
        THROW 50001, 'Invalid order type.', 1;

    IF ISJSON(@ItemsJson) <> 1
        THROW 50002, 'ItemsJson must contain valid JSON.', 1;

    IF @DiscountAmount < 0 OR @TaxRate < 0 OR @DeliveryFee < 0
        THROW 50003, 'Discount, tax rate, and delivery fee cannot be negative.', 1;

    DECLARE @Items TABLE
    (
        MenuItemID INT NOT NULL,
        Quantity INT NOT NULL
    );

    INSERT @Items (MenuItemID, Quantity)
    SELECT MenuItemID, Quantity
    FROM OPENJSON(@ItemsJson)
    WITH
    (
        MenuItemID INT '$.MenuItemID',
        Quantity INT '$.Quantity'
    );

    IF NOT EXISTS (SELECT 1 FROM @Items)
        THROW 50004, 'An order must contain at least one item.', 1;

    IF EXISTS (SELECT 1 FROM @Items WHERE MenuItemID IS NULL OR Quantity IS NULL OR Quantity <= 0)
        THROW 50005, 'Each item needs a valid MenuItemID and positive Quantity.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Items i
        LEFT JOIN dbo.MenuItems m ON m.MenuItemID = i.MenuItemID
        WHERE m.MenuItemID IS NULL OR m.IsAvailable = 0
    )
        THROW 50006, 'One or more menu items do not exist or are unavailable.', 1;

    DECLARE @Subtotal DECIMAL(12,2);
    SELECT @Subtotal = SUM(CONVERT(DECIMAL(12,2), i.Quantity * m.UnitPrice))
    FROM @Items i
    JOIN dbo.MenuItems m ON m.MenuItemID = i.MenuItemID;

    IF @DiscountAmount > @Subtotal
        THROW 50007, 'Discount cannot exceed subtotal.', 1;

    DECLARE @TaxAmount DECIMAL(12,2) =
        CONVERT(DECIMAL(12,2), (@Subtotal - @DiscountAmount) * @TaxRate);
    DECLARE @Total DECIMAL(12,2) =
        @Subtotal - @DiscountAmount + @TaxAmount + @DeliveryFee;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT dbo.RestaurantOrders
        (BranchID, CustomerID, EmployeeID, OrderType, OrderStatus,
         Subtotal, DiscountAmount, TaxAmount, DeliveryFee, TotalAmount, Notes)
        VALUES
        (@BranchID, @CustomerID, @EmployeeID, @OrderType, 'PLACED',
         @Subtotal, @DiscountAmount, @TaxAmount, @DeliveryFee, @Total, @Notes);

        SET @NewOrderID = SCOPE_IDENTITY();

        INSERT dbo.OrderItems (OrderID, MenuItemID, Quantity, UnitPrice)
        SELECT @NewOrderID, i.MenuItemID, i.Quantity, m.UnitPrice
        FROM @Items i
        JOIN dbo.MenuItems m ON m.MenuItemID = i.MenuItemID;

        INSERT dbo.OrderStatusHistory (OrderID, OldStatus, NewStatus)
        VALUES (@NewOrderID, NULL, 'PLACED');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_UpdateOrderStatus
    @OrderID BIGINT,
    @NewStatus VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @NewStatus NOT IN ('PLACED','CONFIRMED','PREPARING','READY','COMPLETED','CANCELLED')
        THROW 50011, 'Invalid order status.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @OldStatus VARCHAR(20);

        SELECT @OldStatus = OrderStatus
        FROM dbo.RestaurantOrders WITH (UPDLOCK, HOLDLOCK)
        WHERE OrderID = @OrderID;

        IF @OldStatus IS NULL
            THROW 50012, 'Order not found.', 1;

        IF @OldStatus IN ('COMPLETED','CANCELLED')
            THROW 50013, 'A completed or cancelled order cannot be changed.', 1;

        UPDATE dbo.RestaurantOrders
        SET OrderStatus = @NewStatus
        WHERE OrderID = @OrderID;

        INSERT dbo.OrderStatusHistory (OrderID, OldStatus, NewStatus)
        VALUES (@OrderID, @OldStatus, @NewStatus);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RecordPayment
    @OrderID BIGINT,
    @PaymentMethod VARCHAR(20),
    @Amount DECIMAL(12,2),
    @TransactionRef VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Amount <= 0
        THROW 50021, 'Payment amount must be greater than zero.', 1;

    IF @PaymentMethod NOT IN ('CASH','CARD','UPI','WALLET','ONLINE')
        THROW 50022, 'Invalid payment method.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.RestaurantOrders WHERE OrderID = @OrderID)
        THROW 50023, 'Order not found.', 1;

    IF @Amount > dbo.fn_OrderPaymentBalance(@OrderID)
        THROW 50024, 'Payment exceeds outstanding balance.', 1;

    INSERT dbo.Payments (OrderID, PaymentMethod, PaymentStatus, Amount, TransactionRef)
    VALUES (@OrderID, @PaymentMethod, 'SUCCESS', @Amount, @TransactionRef);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_AddInventory
    @BranchID INT,
    @InventoryItemID INT,
    @Quantity DECIMAL(12,3),
    @ReferenceText NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Quantity <= 0
        THROW 50031, 'Receipt quantity must be positive.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Branches WHERE BranchID = @BranchID)
            THROW 50032, 'Branch not found.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.InventoryItems WHERE InventoryItemID = @InventoryItemID)
            THROW 50033, 'Inventory item not found.', 1;

        -- InventoryTransactions is the ledger/source of truth. The AFTER INSERT
        -- trigger applies this receipt to BranchInventory exactly once.
        INSERT dbo.InventoryTransactions
        (BranchID, InventoryItemID, TransactionType, QuantityChange, ReferenceText)
        VALUES (@BranchID, @InventoryItemID, 'RECEIPT', @Quantity, @ReferenceText);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

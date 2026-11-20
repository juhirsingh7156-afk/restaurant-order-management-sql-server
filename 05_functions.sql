USE RestaurantOrderManagement;
GO

CREATE OR ALTER FUNCTION dbo.fn_OrderPaymentBalance (@OrderID BIGINT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @OrderTotal DECIMAL(12,2);
    DECLARE @Paid DECIMAL(12,2);

    SELECT @OrderTotal = TotalAmount
    FROM dbo.RestaurantOrders
    WHERE OrderID = @OrderID;

    SELECT @Paid = COALESCE(SUM(Amount), 0)
    FROM dbo.Payments
    WHERE OrderID = @OrderID AND PaymentStatus = 'SUCCESS';

    RETURN COALESCE(@OrderTotal, 0) - COALESCE(@Paid, 0);
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_OrdersForCustomer (@CustomerID INT)
RETURNS TABLE
AS
RETURN
(
    SELECT OrderID, OrderDate, OrderType, OrderStatus, TotalAmount
    FROM dbo.RestaurantOrders
    WHERE CustomerID = @CustomerID
);
GO

/* Payment ledger extensions: partial payments are supported by multiple Payments rows.
   Refunds are separate immutable records. Gateway integration is simulated only. */
USE RestaurantOrderManagement;
GO

CREATE TABLE dbo.PaymentRefunds
(
    RefundID BIGINT IDENTITY(1,1) CONSTRAINT PK_PaymentRefunds PRIMARY KEY,
    PaymentID BIGINT NOT NULL,
    RefundDate DATETIME2(0) NOT NULL CONSTRAINT DF_PaymentRefunds_Date DEFAULT (SYSDATETIME()),
    RefundAmount DECIMAL(12,2) NOT NULL,
    RefundReason NVARCHAR(250) NULL,
    RefundStatus VARCHAR(12) NOT NULL CONSTRAINT DF_PaymentRefunds_Status DEFAULT ('SUCCESS'),
    ExternalRefundRef VARCHAR(100) NULL,
    CONSTRAINT FK_PaymentRefunds_Payments FOREIGN KEY (PaymentID) REFERENCES dbo.Payments(PaymentID),
    CONSTRAINT CK_PaymentRefunds_Amount CHECK (RefundAmount > 0),
    CONSTRAINT CK_PaymentRefunds_Status CHECK (RefundStatus IN ('PENDING','SUCCESS','FAILED'))
);
GO
CREATE UNIQUE INDEX UX_PaymentRefunds_ExternalRefundRef
    ON dbo.PaymentRefunds(ExternalRefundRef) WHERE ExternalRefundRef IS NOT NULL;
GO

CREATE TABLE dbo.DemoGatewayEvents
(
    GatewayEventID BIGINT IDENTITY(1,1) CONSTRAINT PK_DemoGatewayEvents PRIMARY KEY,
    PaymentID BIGINT NULL,
    OrderID BIGINT NOT NULL,
    ProviderName VARCHAR(40) NOT NULL CONSTRAINT DF_DemoGatewayEvents_Provider DEFAULT ('DEMO_GATEWAY'),
    EventType VARCHAR(20) NOT NULL,
    EventStatus VARCHAR(20) NOT NULL,
    ExternalReference VARCHAR(100) NOT NULL,
    Amount DECIMAL(12,2) NOT NULL,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_DemoGatewayEvents_Date DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_DemoGatewayEvents_Payments FOREIGN KEY (PaymentID) REFERENCES dbo.Payments(PaymentID),
    CONSTRAINT FK_DemoGatewayEvents_Orders FOREIGN KEY (OrderID) REFERENCES dbo.RestaurantOrders(OrderID),
    CONSTRAINT UQ_DemoGatewayEvents_ExternalRef UNIQUE (ExternalReference),
    CONSTRAINT CK_DemoGatewayEvents_Type CHECK (EventType IN ('PAYMENT','REFUND')),
    CONSTRAINT CK_DemoGatewayEvents_Status CHECK (EventStatus IN ('SUCCESS','FAILED','PENDING')),
    CONSTRAINT CK_DemoGatewayEvents_Amount CHECK (Amount > 0)
);
GO

/* Records a simulated successful gateway payment. Never stores card numbers, CVV,
   API keys, tokens, or other payment credentials. */
CREATE OR ALTER PROCEDURE dbo.usp_RecordDemoGatewayPayment
    @OrderID BIGINT,
    @Amount DECIMAL(12,2),
    @ExternalReference VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Amount <= 0 THROW 51401, 'Payment amount must be greater than zero.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.RestaurantOrders WHERE OrderID = @OrderID)
        THROW 51402, 'Order does not exist.', 1;
    IF EXISTS (SELECT 1 FROM dbo.DemoGatewayEvents WHERE ExternalReference = @ExternalReference)
        THROW 51403, 'External reference has already been processed.', 1;

    BEGIN TRANSACTION;
    DECLARE @NewPayment TABLE (PaymentID BIGINT);
    INSERT dbo.Payments(OrderID, PaymentMethod, PaymentStatus, Amount, TransactionRef)
    OUTPUT inserted.PaymentID INTO @NewPayment(PaymentID)
    VALUES (@OrderID, 'ONLINE', 'SUCCESS', @Amount, @ExternalReference);

    INSERT dbo.DemoGatewayEvents(PaymentID, OrderID, EventType, EventStatus, ExternalReference, Amount)
    SELECT PaymentID, @OrderID, 'PAYMENT', 'SUCCESS', @ExternalReference, @Amount FROM @NewPayment;
    COMMIT TRANSACTION;
    SELECT PaymentID FROM @NewPayment;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RecordPaymentRefund
    @PaymentID BIGINT,
    @RefundAmount DECIMAL(12,2),
    @RefundReason NVARCHAR(250) = NULL,
    @ExternalRefundRef VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @RefundAmount <= 0 THROW 51411, 'Refund amount must be greater than zero.', 1;

    BEGIN TRANSACTION;
    DECLARE @Paid DECIMAL(12,2), @AlreadyRefunded DECIMAL(12,2), @OrderID BIGINT;
    SELECT @Paid = Amount, @OrderID = OrderID
    FROM dbo.Payments WITH (UPDLOCK, HOLDLOCK)
    WHERE PaymentID = @PaymentID AND PaymentStatus = 'SUCCESS';
    IF @Paid IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51412, 'Payment not found or not eligible for refund.', 1;
    END;
    SELECT @AlreadyRefunded = COALESCE(SUM(RefundAmount), 0)
    FROM dbo.PaymentRefunds WITH (UPDLOCK, HOLDLOCK)
    WHERE PaymentID = @PaymentID AND RefundStatus = 'SUCCESS';
    IF @AlreadyRefunded + @RefundAmount > @Paid
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51413, 'Refund exceeds the remaining refundable payment balance.', 1;
    END;

    INSERT dbo.PaymentRefunds(PaymentID, RefundAmount, RefundReason, ExternalRefundRef)
    VALUES (@PaymentID, @RefundAmount, @RefundReason, @ExternalRefundRef);

    IF @AlreadyRefunded + @RefundAmount = @Paid
        UPDATE dbo.Payments SET PaymentStatus = 'REFUNDED' WHERE PaymentID = @PaymentID;

    INSERT dbo.DemoGatewayEvents(PaymentID, OrderID, EventType, EventStatus, ExternalReference, Amount)
    VALUES (@PaymentID, @OrderID, 'REFUND', 'SUCCESS',
            COALESCE(@ExternalRefundRef, CONCAT('DEMO-REFUND-', @PaymentID, '-', CONVERT(VARCHAR(20), DATEDIFF_BIG(MILLISECOND, '20000101', SYSUTCDATETIME())))),
            @RefundAmount);
    COMMIT TRANSACTION;

    SELECT @PaymentID AS PaymentID, @Paid - @AlreadyRefunded - @RefundAmount AS RemainingRefundableAmount;
END;
GO

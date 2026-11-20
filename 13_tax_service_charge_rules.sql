/* Configurable tax jurisdictions and service-charge rules. */
USE RestaurantOrderManagement;
GO

IF COL_LENGTH('dbo.RestaurantOrders', 'ServiceChargeAmount') IS NULL
    ALTER TABLE dbo.RestaurantOrders ADD ServiceChargeAmount DECIMAL(12,2) NOT NULL
        CONSTRAINT DF_RestaurantOrders_ServiceCharge DEFAULT (0);
GO
IF COL_LENGTH('dbo.RestaurantOrders', 'TaxJurisdictionID') IS NULL
    ALTER TABLE dbo.RestaurantOrders ADD TaxJurisdictionID INT NULL;
GO
IF COL_LENGTH('dbo.RestaurantOrders', 'ServiceChargeRuleID') IS NULL
    ALTER TABLE dbo.RestaurantOrders ADD ServiceChargeRuleID INT NULL;
GO

CREATE TABLE dbo.TaxJurisdictions
(
    TaxJurisdictionID INT IDENTITY(1,1) CONSTRAINT PK_TaxJurisdictions PRIMARY KEY,
    JurisdictionName NVARCHAR(120) NOT NULL,
    CountryCode CHAR(2) NOT NULL,
    StateProvince NVARCHAR(80) NULL,
    City NVARCHAR(80) NULL,
    TaxRate DECIMAL(7,4) NOT NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_TaxJurisdictions_Active DEFAULT (1),
    EffectiveFrom DATE NOT NULL,
    EffectiveTo DATE NULL,
    CONSTRAINT CK_TaxJurisdictions_Rate CHECK (TaxRate >= 0 AND TaxRate <= 100),
    CONSTRAINT CK_TaxJurisdictions_Dates CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom)
);
GO

CREATE TABLE dbo.ServiceChargeRules
(
    ServiceChargeRuleID INT IDENTITY(1,1) CONSTRAINT PK_ServiceChargeRules PRIMARY KEY,
    RuleName NVARCHAR(120) NOT NULL,
    BranchID INT NULL,
    ChargeType VARCHAR(10) NOT NULL,
    ChargeValue DECIMAL(12,4) NOT NULL,
    IsTaxable BIT NOT NULL CONSTRAINT DF_ServiceChargeRules_Taxable DEFAULT (1),
    IsActive BIT NOT NULL CONSTRAINT DF_ServiceChargeRules_Active DEFAULT (1),
    EffectiveFrom DATE NOT NULL,
    EffectiveTo DATE NULL,
    CONSTRAINT FK_ServiceChargeRules_Branches FOREIGN KEY (BranchID) REFERENCES dbo.Branches(BranchID),
    CONSTRAINT CK_ServiceChargeRules_Type CHECK (ChargeType IN ('PERCENT','FIXED')),
    CONSTRAINT CK_ServiceChargeRules_Value CHECK (ChargeValue >= 0 AND (ChargeType <> 'PERCENT' OR ChargeValue <= 100)),
    CONSTRAINT CK_ServiceChargeRules_Dates CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom)
);
GO

ALTER TABLE dbo.RestaurantOrders ADD CONSTRAINT FK_RestaurantOrders_TaxJurisdiction
    FOREIGN KEY (TaxJurisdictionID) REFERENCES dbo.TaxJurisdictions(TaxJurisdictionID);
GO
ALTER TABLE dbo.RestaurantOrders ADD CONSTRAINT FK_RestaurantOrders_ServiceChargeRule
    FOREIGN KEY (ServiceChargeRuleID) REFERENCES dbo.ServiceChargeRules(ServiceChargeRuleID);
GO

/* Calculates and stores tax/service charge snapshots for one order.
   Tax is calculated on discounted subtotal plus taxable service charge.
   DeliveryFee is not included in the taxable base in this demo rule. */
CREATE OR ALTER PROCEDURE dbo.usp_ApplyOrderChargeRules
    @OrderID BIGINT,
    @TaxJurisdictionID INT,
    @ServiceChargeRuleID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Subtotal DECIMAL(12,2), @Discount DECIMAL(12,2), @Delivery DECIMAL(12,2),
            @TaxRate DECIMAL(7,4), @ChargeType VARCHAR(10), @ChargeValue DECIMAL(12,4),
            @ChargeTaxable BIT, @ServiceCharge DECIMAL(12,2), @TaxableBase DECIMAL(12,2),
            @Tax DECIMAL(12,2), @Total DECIMAL(12,2), @BranchID INT;

    SELECT @Subtotal = Subtotal, @Discount = DiscountAmount, @Delivery = DeliveryFee, @BranchID = BranchID
    FROM dbo.RestaurantOrders WHERE OrderID = @OrderID;
    IF @Subtotal IS NULL THROW 51301, 'Order does not exist.', 1;

    SELECT @TaxRate = TaxRate FROM dbo.TaxJurisdictions
    WHERE TaxJurisdictionID = @TaxJurisdictionID AND IsActive = 1
      AND EffectiveFrom <= CONVERT(date, GETDATE())
      AND (EffectiveTo IS NULL OR EffectiveTo >= CONVERT(date, GETDATE()));
    IF @TaxRate IS NULL THROW 51302, 'Tax jurisdiction is inactive or outside its effective dates.', 1;

    SET @ServiceCharge = 0;
    SET @ChargeTaxable = 0;
    IF @ServiceChargeRuleID IS NOT NULL
    BEGIN
        SELECT @ChargeType = ChargeType, @ChargeValue = ChargeValue, @ChargeTaxable = IsTaxable
        FROM dbo.ServiceChargeRules
        WHERE ServiceChargeRuleID = @ServiceChargeRuleID AND IsActive = 1
          AND (BranchID IS NULL OR BranchID = @BranchID)
          AND EffectiveFrom <= CONVERT(date, GETDATE())
          AND (EffectiveTo IS NULL OR EffectiveTo >= CONVERT(date, GETDATE()));
        IF @ChargeType IS NULL THROW 51303, 'Service-charge rule is inactive, invalid for this branch, or outside its effective dates.', 1;
        SET @ServiceCharge = CASE WHEN @ChargeType = 'PERCENT'
            THEN ROUND((@Subtotal - @Discount) * @ChargeValue / 100.0, 2)
            ELSE @ChargeValue END;
    END;

    SET @TaxableBase = (@Subtotal - @Discount) + CASE WHEN @ChargeTaxable = 1 THEN @ServiceCharge ELSE 0 END;
    SET @Tax = ROUND(@TaxableBase * @TaxRate / 100.0, 2);
    SET @Total = (@Subtotal - @Discount) + @ServiceCharge + @Tax + @Delivery;

    UPDATE dbo.RestaurantOrders
    SET TaxAmount = @Tax, ServiceChargeAmount = @ServiceCharge,
        TaxJurisdictionID = @TaxJurisdictionID, ServiceChargeRuleID = @ServiceChargeRuleID,
        TotalAmount = @Total
    WHERE OrderID = @OrderID;

    SELECT @OrderID AS OrderID, @Subtotal AS Subtotal, @Discount AS Discount,
           @ServiceCharge AS ServiceCharge, @Tax AS Tax, @Delivery AS DeliveryFee,
           @Total AS TotalAmount;
END;
GO

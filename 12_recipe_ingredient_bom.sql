/* Recipe / ingredient bill of materials extension.
   Run after the base schema and seed data. Ingredients reuse InventoryItems.
*/
USE RestaurantOrderManagement;
GO

CREATE TABLE dbo.Recipes
(
    RecipeID INT IDENTITY(1,1) CONSTRAINT PK_Recipes PRIMARY KEY,
    MenuItemID INT NOT NULL,
    RecipeName NVARCHAR(120) NOT NULL,
    YieldPortions DECIMAL(10,3) NOT NULL CONSTRAINT DF_Recipes_Yield DEFAULT (1),
    VersionNo INT NOT NULL CONSTRAINT DF_Recipes_Version DEFAULT (1),
    IsActive BIT NOT NULL CONSTRAINT DF_Recipes_Active DEFAULT (1),
    EffectiveFrom DATE NOT NULL CONSTRAINT DF_Recipes_From DEFAULT (CONVERT(date, GETDATE())),
    EffectiveTo DATE NULL,
    CONSTRAINT FK_Recipes_MenuItems FOREIGN KEY (MenuItemID) REFERENCES dbo.MenuItems(MenuItemID),
    CONSTRAINT UQ_Recipes_MenuItem_Version UNIQUE (MenuItemID, VersionNo),
    CONSTRAINT CK_Recipes_Yield CHECK (YieldPortions > 0),
    CONSTRAINT CK_Recipes_EffectiveDates CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom)
);
GO
CREATE UNIQUE INDEX UX_Recipes_OneActivePerMenuItem ON dbo.Recipes(MenuItemID) WHERE IsActive = 1;
GO

CREATE TABLE dbo.RecipeIngredients
(
    RecipeIngredientID BIGINT IDENTITY(1,1) CONSTRAINT PK_RecipeIngredients PRIMARY KEY,
    RecipeID INT NOT NULL,
    InventoryItemID INT NOT NULL,
    QuantityRequired DECIMAL(12,4) NOT NULL,
    PreparationNote NVARCHAR(200) NULL,
    CONSTRAINT FK_RecipeIngredients_Recipes FOREIGN KEY (RecipeID) REFERENCES dbo.Recipes(RecipeID),
    CONSTRAINT FK_RecipeIngredients_InventoryItems FOREIGN KEY (InventoryItemID) REFERENCES dbo.InventoryItems(InventoryItemID),
    CONSTRAINT UQ_RecipeIngredients_Recipe_Item UNIQUE (RecipeID, InventoryItemID),
    CONSTRAINT CK_RecipeIngredients_Quantity CHECK (QuantityRequired > 0)
);
GO

CREATE TABLE dbo.OrderIngredientConsumption
(
    OrderID BIGINT NOT NULL CONSTRAINT PK_OrderIngredientConsumption PRIMARY KEY,
    ConsumedAt DATETIME2(0) NOT NULL CONSTRAINT DF_OrderIngredientConsumption_Date DEFAULT (SYSDATETIME()),
    ConsumedBy SYSNAME NOT NULL CONSTRAINT DF_OrderIngredientConsumption_User DEFAULT (SUSER_SNAME()),
    CONSTRAINT FK_OrderIngredientConsumption_Orders FOREIGN KEY (OrderID) REFERENCES dbo.RestaurantOrders(OrderID)
);
GO

/* Consume ingredients once per order. InventoryTransactions trigger applies stock changes.
   Recipe quantities are defined for the recipe's YieldPortions.
   This procedure is a demo operational workflow; confirm recipe versions and stock policy
   with the business before using in production. */
CREATE OR ALTER PROCEDURE dbo.usp_ConsumeOrderIngredients
    @OrderID BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @BranchID INT;
    SELECT @BranchID = BranchID FROM dbo.RestaurantOrders WHERE OrderID = @OrderID;
    IF @BranchID IS NULL THROW 51201, 'Order does not exist.', 1;

    IF EXISTS (SELECT 1 FROM dbo.OrderIngredientConsumption WHERE OrderID = @OrderID)
        THROW 51202, 'Ingredients have already been consumed for this order.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.OrderItems oi
        WHERE oi.OrderID = @OrderID
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.Recipes r
              WHERE r.MenuItemID = oi.MenuItemID AND r.IsActive = 1
                AND r.EffectiveFrom <= CONVERT(date, GETDATE())
                AND (r.EffectiveTo IS NULL OR r.EffectiveTo >= CONVERT(date, GETDATE()))
          )
    )
        THROW 51203, 'At least one ordered menu item has no active recipe.', 1;

    BEGIN TRANSACTION;

    INSERT dbo.OrderIngredientConsumption(OrderID)
    VALUES (@OrderID);

    INSERT dbo.InventoryTransactions
        (BranchID, InventoryItemID, TransactionType, QuantityChange, ReferenceText)
    SELECT @BranchID, ri.InventoryItemID, 'USAGE',
           -SUM(CONVERT(DECIMAL(12,3), oi.Quantity * ri.QuantityRequired / r.YieldPortions)),
           CONCAT('Recipe consumption for order ', @OrderID)
    FROM dbo.OrderItems oi
    JOIN dbo.Recipes r ON r.MenuItemID = oi.MenuItemID AND r.IsActive = 1
        AND r.EffectiveFrom <= CONVERT(date, GETDATE())
        AND (r.EffectiveTo IS NULL OR r.EffectiveTo >= CONVERT(date, GETDATE()))
    JOIN dbo.RecipeIngredients ri ON ri.RecipeID = r.RecipeID
    WHERE oi.OrderID = @OrderID
    GROUP BY ri.InventoryItemID;

    COMMIT TRANSACTION;
END;
GO

/* Recipe cost estimate based on current inventory-item standard cost is intentionally
   not calculated here because the starter InventoryItems table has no cost column.
   Add a governed cost history model before using recipe costing for decisions. */

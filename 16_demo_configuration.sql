/* Optional fictional configuration data for trying the extension features.
   Run after extension scripts 12-15. Rates are illustrative demo values only,
   not tax or legal advice and not a statement of current statutory rates.
*/
USE RestaurantOrderManagement;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Recipes)
BEGIN
    INSERT dbo.Recipes(MenuItemID, RecipeName, YieldPortions, VersionNo)
    SELECT mi.MenuItemID, CONCAT(mi.ItemName, N' - demo recipe'), 1, 1
    FROM dbo.MenuItems mi
    WHERE mi.ItemName IN (N'Paneer Tikka', N'Veg Biryani');

    INSERT dbo.RecipeIngredients(RecipeID, InventoryItemID, QuantityRequired, PreparationNote)
    SELECT r.RecipeID, i.InventoryItemID,
           CASE WHEN i.ItemName = N'Paneer' THEN 0.2000
                WHEN i.ItemName = N'Basmati Rice' THEN 0.1800
                ELSE 0.0300 END,
           N'Illustrative synthetic bill of materials'
    FROM dbo.Recipes r
    JOIN dbo.InventoryItems i ON
       (r.RecipeName LIKE N'Paneer Tikka%' AND i.ItemName IN (N'Paneer', N'Cooking Oil'))
       OR (r.RecipeName LIKE N'Veg Biryani%' AND i.ItemName IN (N'Basmati Rice', N'Cooking Oil'));
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.TaxJurisdictions WHERE JurisdictionName = N'Demo Pune Tax')
    INSERT dbo.TaxJurisdictions
        (JurisdictionName, CountryCode, StateProvince, City, TaxRate, EffectiveFrom)
    VALUES (N'Demo Pune Tax', 'IN', N'Maharashtra', N'Pune', 5.0000, '2020-01-01');
GO

IF NOT EXISTS (SELECT 1 FROM dbo.ServiceChargeRules WHERE RuleName = N'Demo 5 Percent Service Charge')
    INSERT dbo.ServiceChargeRules
        (RuleName, BranchID, ChargeType, ChargeValue, IsTaxable, EffectiveFrom)
    VALUES (N'Demo 5 Percent Service Charge', NULL, 'PERCENT', 5.0000, 1, '2020-01-01');
GO

SELECT 'Demo extension configuration ready' AS SetupStatus,
       (SELECT COUNT(*) FROM dbo.Recipes) AS RecipeCount,
       (SELECT COUNT(*) FROM dbo.RecipeIngredients) AS RecipeIngredientCount,
       (SELECT COUNT(*) FROM dbo.TaxJurisdictions) AS TaxRuleCount,
       (SELECT COUNT(*) FROM dbo.ServiceChargeRules) AS ServiceChargeRuleCount;
GO

/* Database-level roles and least-privilege grants.
   Run as a database owner/admin. Map real server logins to these roles separately.
   This script does not create SQL Server logins or store passwords.
*/
USE RestaurantOrderManagement;
GO

IF DATABASE_PRINCIPAL_ID('Restaurant_ReadOnly') IS NULL CREATE ROLE Restaurant_ReadOnly;
IF DATABASE_PRINCIPAL_ID('Restaurant_Operations') IS NULL CREATE ROLE Restaurant_Operations;
IF DATABASE_PRINCIPAL_ID('Restaurant_Finance') IS NULL CREATE ROLE Restaurant_Finance;
IF DATABASE_PRINCIPAL_ID('Restaurant_Administrator') IS NULL CREATE ROLE Restaurant_Administrator;
GO

/* Read-only access through reporting views, not unrestricted base-table access. */
GRANT SELECT ON OBJECT::dbo.vw_DailyBranchSales TO Restaurant_ReadOnly;
GRANT SELECT ON OBJECT::dbo.vw_CustomerLifetimeValue TO Restaurant_ReadOnly;
GRANT SELECT ON OBJECT::dbo.vw_InventoryReorderAlerts TO Restaurant_ReadOnly;
GO

/* Operational staff can execute approved order and stock workflows. */
GRANT EXECUTE ON OBJECT::dbo.usp_PlaceOrder TO Restaurant_Operations;
GRANT EXECUTE ON OBJECT::dbo.usp_UpdateOrderStatus TO Restaurant_Operations;
GRANT EXECUTE ON OBJECT::dbo.usp_AddInventory TO Restaurant_Operations;
GRANT EXECUTE ON OBJECT::dbo.usp_ConsumeOrderIngredients TO Restaurant_Operations;
GO

/* Finance role can read financial tables and execute approved financial procedures. */
GRANT SELECT ON OBJECT::dbo.RestaurantOrders TO Restaurant_Finance;
GRANT SELECT ON OBJECT::dbo.Payments TO Restaurant_Finance;
GRANT SELECT ON OBJECT::dbo.PaymentRefunds TO Restaurant_Finance;
GRANT EXECUTE ON OBJECT::dbo.usp_ApplyOrderChargeRules TO Restaurant_Finance;
GRANT EXECUTE ON OBJECT::dbo.usp_RecordDemoGatewayPayment TO Restaurant_Finance;
GRANT EXECUTE ON OBJECT::dbo.usp_RecordPaymentRefund TO Restaurant_Finance;
GO

/* Administrator role receives database-level control; assign only to trusted DB admins. */
ALTER ROLE db_owner ADD MEMBER Restaurant_Administrator;
GO

/* Example membership mapping (replace with an already-created database user):
   ALTER ROLE Restaurant_ReadOnly ADD MEMBER [your_reporting_database_user];
   ALTER ROLE Restaurant_Operations ADD MEMBER [your_pos_database_user];
   ALTER ROLE Restaurant_Finance ADD MEMBER [your_finance_database_user];
   Never commit real login names, passwords, connection strings, or secrets.
*/

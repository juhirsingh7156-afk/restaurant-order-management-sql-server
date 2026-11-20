# Advanced database extensions (excluding Power BI)

These optional SQL Server extensions build on the original Restaurant Order Management schema. They are portfolio demonstrations and must be tested in a disposable development database before use.

## Deployment order

After the original scripts `00` through `09`, run:

1. `sql/extensions/12_recipe_ingredient_bom.sql`
2. `sql/extensions/13_tax_service_charge_rules.sql`
3. `sql/extensions/14_refunds_and_demo_gateway.sql`
4. `sql/extensions/15_database_security_roles.sql`
5. Optional: `sql/extensions/16_demo_configuration.sql` for clearly labelled fictional recipe/tax/service-charge setup.

The existing `sql/10_synthetic_dataset.sql` adds 2,000 synthetic orders and 4,000 order lines. Run it once after the original schema, seed, and supporting objects. `sql/11_performance_demo.sql` is a separate experiment; capture your own actual execution plans and IO/time results.

## 1. Authentication, authorization and roles

`15_database_security_roles.sql` creates database roles for read-only reporting, restaurant operations, finance, and administrators. It grants access to reporting views or approved stored procedures instead of giving every user unrestricted table access.

This script creates database roles, **not server logins or user passwords**. A DBA must provision identities using the organization's approved identity process and map each database user to the appropriate role. Example membership statements are commented in the script. Do not commit credentials or connection strings.

## 2. Recipe / ingredient bill of materials

`12_recipe_ingredient_bom.sql` adds:

- `Recipes`: menu item, recipe version, yield portions, effective dates and active status.
- `RecipeIngredients`: ingredient inventory item and quantity required per recipe yield.
- `OrderIngredientConsumption`: one-time consumption marker per order.
- `usp_ConsumeOrderIngredients`: converts ordered menu quantities into signed inventory usage transactions. The existing inventory ledger trigger applies stock movements and rejects negative stock.

Ingredient quantities use the inventory item's unit of measure. Ensure all recipe quantities are entered in the same unit. The demo does not yet include supplier purchasing, ingredient cost history, substitutions, allergens, waste approval, or full recipe version migration.

Example after loading demo configuration and confirming order 1 contains menu items with active recipes:

```sql
EXEC dbo.usp_ConsumeOrderIngredients @OrderID = 1;
SELECT * FROM dbo.BranchInventory ORDER BY BranchID, InventoryItemID;
SELECT * FROM dbo.InventoryTransactions
WHERE ReferenceText LIKE N'Recipe consumption%'
ORDER BY InventoryTransactionID DESC;
```

Consumption is intentionally one-time per order. Test on a disposable database because the procedure changes inventory balances.

## 3. Tax jurisdictions and configurable service charges

`13_tax_service_charge_rules.sql` adds effective-dated tax jurisdictions and service-charge rules. `usp_ApplyOrderChargeRules` applies a selected rule to an order and stores the resulting tax/service-charge amounts as order snapshots.

The demonstration calculates tax on discounted subtotal plus a service charge only when that service-charge rule is marked taxable. Delivery fees are excluded from the taxable base in this example. Actual tax treatment varies by jurisdiction and business model. The values in `16_demo_configuration.sql` are illustrative only; replace them with reviewed, legally approved rules before any real use.

Example:

```sql
DECLARE @TaxID INT = (SELECT TOP (1) TaxJurisdictionID
                      FROM dbo.TaxJurisdictions
                      WHERE JurisdictionName = N'Demo Pune Tax');
DECLARE @ChargeID INT = (SELECT TOP (1) ServiceChargeRuleID
                         FROM dbo.ServiceChargeRules
                         WHERE RuleName = N'Demo 5 Percent Service Charge');
EXEC dbo.usp_ApplyOrderChargeRules
    @OrderID = 1,
    @TaxJurisdictionID = @TaxID,
    @ServiceChargeRuleID = @ChargeID;
```

## 4. Partial payments, refunds and payment gateway demonstration

The existing `Payments` table supports multiple successful payment rows per order, allowing split/partial payments. `PaymentRefunds` stores refund events separately from the original payment. `usp_RecordPaymentRefund` prevents cumulative successful refunds from exceeding the original payment amount and marks the payment `REFUNDED` only when fully refunded.

`usp_RecordDemoGatewayPayment` and `DemoGatewayEvents` simulate an online payment event. They do not connect to a real provider. A production integration must be implemented in a secure application/service layer using provider-hosted tokenization, verified webhooks, idempotency, reconciliation, and secret management. Never store PAN, CVV, API secrets, or access tokens in this database or repository.

Example (use a disposable order/payment):

```sql
EXEC dbo.usp_RecordDemoGatewayPayment
    @OrderID = 1,
    @Amount = 100.00,
    @ExternalReference = 'DEMO-PAY-ORDER1-001';

DECLARE @PaymentID BIGINT = (SELECT TOP (1) PaymentID
                             FROM dbo.Payments
                             WHERE TransactionRef = 'DEMO-PAY-ORDER1-001');
EXEC dbo.usp_RecordPaymentRefund
    @PaymentID = @PaymentID,
    @RefundAmount = 25.00,
    @RefundReason = N'Demo partial refund',
    @ExternalRefundRef = 'DEMO-REFUND-ORDER1-001';
```

## 5. Deployment automation and CI validation

- `scripts/deploy.sqlcmd.ps1` deploys the base schema, seed data, and extension scripts in order using `sqlcmd`. Run it from PowerShell on a machine with SQL Server command-line tools installed and a SQL Server instance you are authorized to modify.
- `.github/workflows/sql-validation.yml` runs SQLFluff's T-SQL parser against repository SQL files on pushes and pull requests.

The GitHub workflow is static parsing, not a live SQL Server integration test. It does not prove that scripts deploy successfully or that business workflows pass. A stronger CI pipeline can be added later using an isolated SQL Server service/container and automated test data.

Example deployment command:

```powershell
./scripts/deploy.sqlcmd.ps1 -ServerInstance "localhost" -TrustServerCertificate
```

Run `10_synthetic_dataset.sql`, `11_performance_demo.sql`, and `16_demo_configuration.sql` separately as needed. Do not run the synthetic loader repeatedly without resetting the database.

## 6. Performance evidence

Use `sql/11_performance_demo.sql` after the synthetic dataset is loaded. In SSMS enable **Include Actual Execution Plan** (`Ctrl+M`) and capture:

- Before: actual plan, `STATISTICS IO`, and `STATISTICS TIME` output.
- After: actual plan, `STATISTICS IO`, and `STATISTICS TIME` output.

Record observed values in `docs/performance_analysis.md`. Do not claim a specific percentage improvement until it has been measured on your SQL Server instance. Query plans vary with SQL Server version, data volume, statistics, cache state and optimizer decisions.

## Known limitations

This is an educational portfolio extension, not a certified production POS or payment system. It does not provide application login, a real payment provider connection, legally maintained tax tables, multi-currency settlement, chargeback processing, accounting integration, supplier procurement, or full audit/compliance controls. Test schema changes and financial workflows with synthetic data before publishing or demonstrating them.

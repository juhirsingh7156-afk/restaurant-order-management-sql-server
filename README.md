# Restaurant Order Management System (Microsoft SQL Server)

A portfolio-ready relational database project for a multi-branch restaurant. It demonstrates SQL Server database design, T-SQL querying, business rules, transaction handling, reporting, indexing, and test scenarios.

## Business problem

A restaurant group needs one system to manage branches, staff, customers, menu items, orders, order line items, payments, and inventory. Managers also need reliable sales and operations reporting.

## Technology

- Microsoft SQL Server 2019+ (SQL Server 2022 recommended)
- SQL Server Management Studio (SSMS) or Azure Data Studio
- T-SQL
- Git / GitHub

## Repository structure

```text
restaurant-order-management-sql-server/
├── README.md
├── .gitignore
├── sql/
│   ├── 00_create_database.sql through 09_test_cases.sql
│   ├── 10_synthetic_dataset.sql
│   ├── 11_performance_demo.sql
│   └── extensions/             # recipe BOM, tax/service charges, refunds, roles
└── docs/
    ├── data_dictionary.md
    ├── business_rules.md
    ├── interview_questions.md
    ├── erd.mmd
    ├── erd.png
    ├── portfolio_evidence.md
    ├── performance_analysis.md
    └── advanced_extensions.md
    ├── screenshots/   # Add your real SSMS screenshots here
    └── demo/          # Add your optional demo video/GIF here
```

## How to run

Run scripts in this order in SSMS:

1. `00_create_database.sql` — creates and selects the database.
2. `01_schema.sql` — creates tables, keys, constraints, and relationships.
3. `02_seed_data.sql` — inserts reproducible sample data.
4. `03_indexes.sql` — creates supporting indexes.
5. `04_views.sql` — creates reporting views.
6. `05_functions.sql` — creates scalar/table-valued functions.
7. `06_stored_procedures.sql` — creates order and inventory procedures.
8. `07_triggers.sql` — creates audit and stock-protection triggers.
9. `08_analysis_queries.sql` — run individual business analysis queries.
10. `09_test_cases.sql` — run the validation scenarios and inspect expected outcomes.
11. `10_synthetic_dataset.sql` — optional: adds 2,000 clearly labelled synthetic orders and 4,000 order lines. Run once on a fresh database.
12. `11_performance_demo.sql` — optional: compare a branch/date sales query before and after a covering index.

Use a SQL Server instance where you have permission to create databases. The scripts target SQL Server 2019+.

## Main entities

- `Branches`, `Employees`, `Customers`
- `Categories`, `MenuItems`
- `RestaurantOrders`, `OrderItems`
- `Payments`
- `InventoryItems`, `BranchInventory`, `InventoryTransactions`
- `OrderStatusHistory`, `OrderAudit`

## Key features

- Normalized relational design with primary/foreign keys and check constraints.
- Multi-branch ordering, dine-in/takeaway/delivery channels.
- Order creation in a transaction with input validation and order-line creation. Inventory receipts and recipe-based ingredient usage update stock through the inventory ledger trigger.
- Payment recording with duplicate-payment protection.
- Order status history and audit trail.
- Views for order details, daily sales, and inventory alerts.
- Stored procedures for placing orders and changing order status.
- Window functions, CTEs, date analysis, ranking, and customer segmentation examples.
- Indexes aligned to common reporting and lookup patterns.

## Important design decisions

1. Monetary values use `DECIMAL(12,2)`, not `FLOAT`.
2. Order line items store the unit price at the time of sale. This preserves historical invoice values if menu prices change later.
3. Order status changes are recorded in `OrderStatusHistory`.
4. Inventory is tracked by branch. Inventory transactions are the ledger/source of truth; the insert trigger applies each movement to the branch balance once. The optional recipe/BOM extension records ingredient quantities and consumes them once per order.
5. The order placement procedure uses `XACT_ABORT`, `TRY/CATCH`, and a transaction. Production deployments should also consider idempotency keys, deadlock retry policy, and stronger authorization.

## Suggested GitHub project description

**Restaurant Order Management System | Microsoft SQL Server | T-SQL | Stored Procedures | Views | Triggers | Window Functions | Reporting**

## Production-readiness limitations

This is a portfolio/demo database, not a production POS. The advanced extensions demonstrate database roles, recipe/BOM consumption, configurable tax/service-charge rules, partial-payment/refund records, a simulated gateway workflow, and basic deployment/CI automation. Production use still requires real identity provisioning, legally reviewed tax configuration, an actual secure payment-provider integration, application-level authorization, idempotency and reconciliation, robust automated integration tests, backups, monitoring, and operational/security review.


## ERD

![Entity relationship diagram](docs/erd.png)

The editable Mermaid source is `docs/erd.mmd`.

## Synthetic data and performance evidence

- `sql/10_synthetic_dataset.sql` adds 2,000 fictional orders and 4,000 order lines. All generated order notes are explicitly labelled synthetic.
- `sql/11_performance_demo.sql` demonstrates a covering-index comparison. Capture your actual execution plans and record measured statistics in `docs/performance_analysis.md`.
- Follow `docs/portfolio_evidence.md` to capture genuine SSMS screenshots and an optional short demo recording. Empty screenshot/demo folders are intentional until you add your own captures.

## Security and privacy

This repository is designed to use fictional demonstration data only. Never commit real customer records, passwords, API keys, connection strings, `.bak` files, database files, or screenshots containing server/user details. Review `git diff --cached` before every push.

## Publish this project on GitHub

1. Create a new **public** GitHub repository named `restaurant-order-management-sql-server` (do not initialize it with another README).
2. Extract this project ZIP and open a terminal in the extracted project folder.
3. Run:

```bash
git init
git add .
git status
git commit -m "Add restaurant order management SQL Server project"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/restaurant-order-management-sql-server.git
git push -u origin main
```

4. Before pushing, inspect `git status` and the staged file list. Confirm there are no real customer records, secrets, credentials, connection strings, database backups, or unredacted screenshots.
5. After you capture your SSMS evidence, add the images under `docs/screenshots/` and the recording under `docs/demo/`, then commit and push again.

Suggested GitHub repository description:

> Multi-branch restaurant order management database built with Microsoft SQL Server and T-SQL. Includes normalized schema, stored procedures, triggers, reporting queries, synthetic data, ERD, and an index performance experiment.

## Advanced extensions (excluding Power BI)

The repository now includes optional advanced SQL Server extensions under `sql/extensions/`:

- `12_recipe_ingredient_bom.sql` — recipe versions, ingredient bill of materials, and one-time order ingredient consumption through the inventory ledger.
- `13_tax_service_charge_rules.sql` — effective-dated tax jurisdictions, configurable service-charge rules, and order charge calculation.
- `14_refunds_and_demo_gateway.sql` — multiple/partial payments, refund ledger, refund limits, and a simulated gateway event workflow (not a real payment integration).
- `15_database_security_roles.sql` — least-privilege database roles and grants for reporting, operations, finance, and administrators.
- `16_demo_configuration.sql` — optional fictional demo recipes and illustrative tax/service-charge rules.

See [`docs/advanced_extensions.md`](docs/advanced_extensions.md) for deployment order, examples, security notes, limitations, and validation instructions.

### Automated deployment and CI

- `scripts/deploy.sqlcmd.ps1` deploys the base schema and advanced extension scripts using `sqlcmd`.
- `.github/workflows/sql-validation.yml` performs static T-SQL parsing on pushes and pull requests. This is not a live SQL Server deployment test.

### Important scope notes

The payment gateway workflow is simulated; no external provider is connected. Database roles are created, but server logins and user identities must be provisioned separately by an administrator. Tax values in the demo setup are illustrative only and must not be treated as legal tax guidance. The synthetic dataset is fictional. Do not use real customer data, secrets, credentials, card data, or connection strings in this repository.

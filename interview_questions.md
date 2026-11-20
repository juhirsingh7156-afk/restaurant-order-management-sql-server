# Interview talking points

## Database design
- Why separate `RestaurantOrders` and `OrderItems`? The header stores order-level facts; the child table stores the repeating product lines. This avoids repeating order-level data and supports one-to-many relationships.
- Why store `UnitPrice` in `OrderItems` when `MenuItems` already has `UnitPrice`? It preserves the historical selling price if the menu price changes later.
- Why use `DECIMAL` for money? It provides exact decimal arithmetic; floating-point types can introduce representation errors.

## T-SQL
- `WHERE` filters rows before grouping; `HAVING` filters groups after aggregation.
- A CTE improves readability and can structure multi-step logic; it is not automatically materialized.
- `ROW_NUMBER` assigns a unique sequence within a partition; `RANK` and `DENSE_RANK` handle ties differently.
- `LAG` accesses a previous row in an ordered window, useful for month-over-month comparisons.
- A LEFT JOIN preserves unmatched rows from the left side, useful for customers with no orders.

## Transactions and concurrency
- `BEGIN TRANSACTION`, `COMMIT`, and `ROLLBACK` keep order header and detail inserts atomic.
- `SET XACT_ABORT ON` helps ensure many runtime errors terminate and roll back the transaction.
- `TRY/CATCH` provides a controlled error path; `XACT_STATE()` determines whether a transaction can be committed or must be rolled back.
- `UPDLOCK` and `HOLDLOCK` are used in the status update path to reduce conflicting concurrent changes. Locking strategy should be validated under expected workload.

## Performance
- Indexes support frequent filters, joins, and sorts; every index also adds write and storage overhead.
- Included columns can cover queries without making every selected column part of the index key.
- Use actual execution plans and `SET STATISTICS IO, TIME ON` to compare query behavior.
- Avoid wrapping indexed columns in functions in predicates when a sargable range predicate can be used.

## Limitations to acknowledge honestly
- The demo order procedure does not deduct recipe ingredients.
- Tax is a parameter, not a jurisdiction-aware tax engine.
- The demo uses a simplified status transition policy.
- A real payment integration needs idempotency, reconciliation, secure secrets handling, and refund workflows.

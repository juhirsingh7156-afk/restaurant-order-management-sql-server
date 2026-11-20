# Performance improvement: covering index for branch/date sales

## Query pattern

The report filters `RestaurantOrders` by an equality predicate on `BranchID` and a date range on `OrderDate`, then aggregates `TotalAmount`. A table scan or a non-covering access path may read more pages and perform extra lookups as the order table grows.

## Change

`sql/11_performance_demo.sql` compares the same report before and after creating this covering nonclustered index:

```sql
CREATE INDEX IX_Demo_Branch_Date_Cover
ON dbo.RestaurantOrders(BranchID, OrderDate)
INCLUDE (TotalAmount, OrderStatus);
```

The key columns match the equality-then-range predicates. `TotalAmount` is included so the revenue aggregation can be served from the index without a key lookup for that column.

## Evidence required

Run the demo against the synthetic dataset with Actual Execution Plan and `SET STATISTICS IO, TIME ON`. Compare logical reads, CPU time, elapsed time, and plan operators. Depending on row count, SQL Server version, statistics, cache state, and cost estimates, it may choose a scan for either query; that is valid optimizer behavior. For a fair comparison, execute both after warming the cache and repeat several times.

| Metric | Before | After |
|---|---:|---:|
| Logical reads | Fill from SSMS | Fill from SSMS |
| CPU time (ms) | Fill from SSMS | Fill from SSMS |
| Elapsed time (ms) | Fill from SSMS | Fill from SSMS |
| Chosen plan operators | Describe actual plan | Describe actual plan |

**Do not claim a numeric improvement until you measure it.** Add your two actual plan screenshots to `docs/screenshots/` and update this table. An index also adds storage and write overhead, so retain it only if the measured workload justifies it.

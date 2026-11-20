# Portfolio evidence capture guide

This repository includes the ERD source and a rendered ERD image. The remaining SQL Server screenshots must be captured from your own successful SSMS run; do not use mock screenshots as proof of execution.

## Evidence to add

Save files in `docs/screenshots/` using these names:

1. `01-erd.png` — provided ERD image (`docs/erd.png`); optionally replace with your own SSMS/diagram-tool export.
2. `02-schema-tables.png` — SSMS Object Explorer expanded to Tables, showing the created tables.
3. `03-stored-procedure.png` — execute `dbo.usp_PlaceOrder` with the example in `sql/09_test_cases.sql`; show the query and successful output. Hide server/user details.
4. `04-sales-report.png` — run a query from `sql/08_analysis_queries.sql` or select from a reporting view; show result grid.
5. `05-plan-before.png` and `06-plan-after.png` — actual execution plans for the two sections in `sql/11_performance_demo.sql`.

## How to capture in SSMS

- Run scripts `00` through `09` in the order documented in README.
- Run `10_synthetic_dataset.sql` once to add 2,000 synthetic orders and 4,000 order lines.
- Open `11_performance_demo.sql`; enable **Include Actual Execution Plan** with `Ctrl+M`. Run the BEFORE query, save a screenshot of the plan and Messages tab. Run the AFTER section and save the second screenshot.
- Record the logical reads and CPU/elapsed time from `SET STATISTICS IO/TIME`. Put measured values in `docs/performance_analysis.md`; do not invent numbers.
- Crop screenshots so no server names, usernames, credentials, or unrelated personal information are visible.

## Optional demo video/GIF storyboard (60–90 seconds)

1. Show the ERD (5–10 sec).
2. Expand tables in SSMS (10 sec).
3. Execute the order procedure and show the new OrderID (15 sec).
4. Run a sales report (15 sec).
5. Show the before/after execution plans (15–25 sec).
6. End on the GitHub README and repository tree (5 sec).

Use OBS, Windows Snipping Tool screen recording, or another recorder. Export a compressed MP4 or GIF to `docs/demo/`.

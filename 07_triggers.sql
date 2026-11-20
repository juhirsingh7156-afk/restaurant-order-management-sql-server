USE RestaurantOrderManagement;
GO

/*
  Multi-row safe trigger: records every status change in the audit table.
  The stored procedure also writes business status history; this audit is a
  database-level change trail and can capture direct updates as well.
*/
CREATE OR ALTER TRIGGER dbo.trg_Orders_StatusAudit
ON dbo.RestaurantOrders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT dbo.OrderAudit (OrderID, OldStatus, NewStatus, AuditAction)
    SELECT i.OrderID, d.OrderStatus, i.OrderStatus, 'STATUS_UPDATE'
    FROM inserted i
    JOIN deleted d ON d.OrderID = i.OrderID
    WHERE ISNULL(i.OrderStatus, '') <> ISNULL(d.OrderStatus, '');
END;
GO

/*
  Inventory transaction ledger trigger.
  QuantityChange is signed: receipts are positive; usage/waste are negative.
  The trigger rejects a transaction that would make stock negative.
*/
CREATE OR ALTER TRIGGER dbo.trg_InventoryTransactions_ApplyStock
ON dbo.InventoryTransactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM
        (
            SELECT BranchID, InventoryItemID, SUM(QuantityChange) AS NetChange
            FROM inserted
            GROUP BY BranchID, InventoryItemID
        ) x
        LEFT JOIN dbo.BranchInventory bi WITH (UPDLOCK, HOLDLOCK)
          ON bi.BranchID = x.BranchID AND bi.InventoryItemID = x.InventoryItemID
        WHERE COALESCE(bi.QuantityOnHand, 0) + x.NetChange < 0
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50041, 'Inventory transaction would result in negative stock.', 1;
    END;

    UPDATE bi
    SET bi.QuantityOnHand = bi.QuantityOnHand + x.NetChange,
        bi.LastUpdated = SYSDATETIME()
    FROM dbo.BranchInventory bi
    JOIN
    (
        SELECT BranchID, InventoryItemID, SUM(QuantityChange) AS NetChange
        FROM inserted
        GROUP BY BranchID, InventoryItemID
    ) x ON x.BranchID = bi.BranchID AND x.InventoryItemID = bi.InventoryItemID;

    INSERT dbo.BranchInventory (BranchID, InventoryItemID, QuantityOnHand)
    SELECT x.BranchID, x.InventoryItemID, x.NetChange
    FROM
    (
        SELECT BranchID, InventoryItemID, SUM(QuantityChange) AS NetChange
        FROM inserted
        GROUP BY BranchID, InventoryItemID
    ) x
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.BranchInventory bi
        WHERE bi.BranchID = x.BranchID AND bi.InventoryItemID = x.InventoryItemID
    );
END;
GO

USE RestaurantOrderManagement;
GO

CREATE TABLE dbo.Branches
(
    BranchID       INT IDENTITY(1,1) CONSTRAINT PK_Branches PRIMARY KEY,
    BranchName     NVARCHAR(100) NOT NULL,
    Phone          VARCHAR(20) NULL,
    Email          VARCHAR(254) NULL,
    AddressLine    NVARCHAR(200) NOT NULL,
    City           NVARCHAR(80) NOT NULL,
    StateProvince  NVARCHAR(80) NULL,
    PostalCode     VARCHAR(15) NULL,
    IsActive       BIT NOT NULL CONSTRAINT DF_Branches_IsActive DEFAULT (1),
    CreatedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_Branches_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT UQ_Branches_Name_City UNIQUE (BranchName, City)
);
GO

CREATE TABLE dbo.Employees
(
    EmployeeID    INT IDENTITY(1,1) CONSTRAINT PK_Employees PRIMARY KEY,
    BranchID      INT NOT NULL,
    FirstName     NVARCHAR(60) NOT NULL,
    LastName      NVARCHAR(60) NOT NULL,
    JobTitle      NVARCHAR(60) NOT NULL,
    Email         VARCHAR(254) NULL,
    Phone         VARCHAR(20) NULL,
    HireDate      DATE NOT NULL,
    IsActive      BIT NOT NULL CONSTRAINT DF_Employees_IsActive DEFAULT (1),
    CONSTRAINT FK_Employees_Branches FOREIGN KEY (BranchID) REFERENCES dbo.Branches(BranchID),
    CONSTRAINT UQ_Employees_Email UNIQUE (Email)
);
GO

CREATE TABLE dbo.Customers
(
    CustomerID    INT IDENTITY(1,1) CONSTRAINT PK_Customers PRIMARY KEY,
    FirstName     NVARCHAR(60) NOT NULL,
    LastName      NVARCHAR(60) NOT NULL,
    Email         VARCHAR(254) NULL,
    Phone         VARCHAR(20) NULL,
    CreatedAt     DATETIME2(0) NOT NULL CONSTRAINT DF_Customers_CreatedAt DEFAULT (SYSDATETIME()),
    IsActive      BIT NOT NULL CONSTRAINT DF_Customers_IsActive DEFAULT (1),
    CONSTRAINT UQ_Customers_Email UNIQUE (Email)
);
GO

CREATE TABLE dbo.Categories
(
    CategoryID    INT IDENTITY(1,1) CONSTRAINT PK_Categories PRIMARY KEY,
    CategoryName  NVARCHAR(80) NOT NULL CONSTRAINT UQ_Categories_Name UNIQUE,
    Description   NVARCHAR(250) NULL,
    IsActive      BIT NOT NULL CONSTRAINT DF_Categories_IsActive DEFAULT (1)
);
GO

CREATE TABLE dbo.MenuItems
(
    MenuItemID    INT IDENTITY(1,1) CONSTRAINT PK_MenuItems PRIMARY KEY,
    CategoryID    INT NOT NULL,
    ItemName      NVARCHAR(120) NOT NULL,
    Description   NVARCHAR(500) NULL,
    UnitPrice     DECIMAL(12,2) NOT NULL,
    IsAvailable   BIT NOT NULL CONSTRAINT DF_MenuItems_IsAvailable DEFAULT (1),
    IsStockTracked BIT NOT NULL CONSTRAINT DF_MenuItems_IsStockTracked DEFAULT (0),
    CreatedAt     DATETIME2(0) NOT NULL CONSTRAINT DF_MenuItems_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_MenuItems_Categories FOREIGN KEY (CategoryID) REFERENCES dbo.Categories(CategoryID),
    CONSTRAINT UQ_MenuItems_ItemName UNIQUE (ItemName),
    CONSTRAINT CK_MenuItems_UnitPrice CHECK (UnitPrice >= 0)
);
GO

CREATE TABLE dbo.RestaurantOrders
(
    OrderID        BIGINT IDENTITY(1,1) CONSTRAINT PK_RestaurantOrders PRIMARY KEY,
    BranchID       INT NOT NULL,
    CustomerID     INT NULL,
    EmployeeID     INT NULL,
    OrderDate      DATETIME2(0) NOT NULL CONSTRAINT DF_Orders_OrderDate DEFAULT (SYSDATETIME()),
    OrderType      VARCHAR(20) NOT NULL,
    OrderStatus    VARCHAR(20) NOT NULL CONSTRAINT DF_Orders_Status DEFAULT ('PLACED'),
    Subtotal       DECIMAL(12,2) NOT NULL CONSTRAINT DF_Orders_Subtotal DEFAULT (0),
    DiscountAmount DECIMAL(12,2) NOT NULL CONSTRAINT DF_Orders_Discount DEFAULT (0),
    TaxAmount      DECIMAL(12,2) NOT NULL CONSTRAINT DF_Orders_Tax DEFAULT (0),
    DeliveryFee    DECIMAL(12,2) NOT NULL CONSTRAINT DF_Orders_DeliveryFee DEFAULT (0),
    TotalAmount    DECIMAL(12,2) NOT NULL CONSTRAINT DF_Orders_Total DEFAULT (0),
    Notes          NVARCHAR(500) NULL,
    CreatedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_Orders_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_Orders_Branches FOREIGN KEY (BranchID) REFERENCES dbo.Branches(BranchID),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID),
    CONSTRAINT FK_Orders_Employees FOREIGN KEY (EmployeeID) REFERENCES dbo.Employees(EmployeeID),
    CONSTRAINT CK_Orders_Type CHECK (OrderType IN ('DINE_IN','TAKEAWAY','DELIVERY')),
    CONSTRAINT CK_Orders_Status CHECK (OrderStatus IN ('PLACED','CONFIRMED','PREPARING','READY','COMPLETED','CANCELLED')),
    CONSTRAINT CK_Orders_Amounts CHECK
      (Subtotal >= 0 AND DiscountAmount >= 0 AND TaxAmount >= 0 AND DeliveryFee >= 0 AND TotalAmount >= 0),
    CONSTRAINT CK_Orders_Discount CHECK (DiscountAmount <= Subtotal)
);
GO

CREATE TABLE dbo.OrderItems
(
    OrderItemID   BIGINT IDENTITY(1,1) CONSTRAINT PK_OrderItems PRIMARY KEY,
    OrderID       BIGINT NOT NULL,
    MenuItemID    INT NOT NULL,
    Quantity      INT NOT NULL,
    UnitPrice     DECIMAL(12,2) NOT NULL,
    LineTotal     AS CONVERT(DECIMAL(12,2), Quantity * UnitPrice) PERSISTED,
    SpecialInstructions NVARCHAR(250) NULL,
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (OrderID) REFERENCES dbo.RestaurantOrders(OrderID),
    CONSTRAINT FK_OrderItems_MenuItems FOREIGN KEY (MenuItemID) REFERENCES dbo.MenuItems(MenuItemID),
    CONSTRAINT CK_OrderItems_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_OrderItems_UnitPrice CHECK (UnitPrice >= 0)
);
GO

CREATE TABLE dbo.Payments
(
    PaymentID       BIGINT IDENTITY(1,1) CONSTRAINT PK_Payments PRIMARY KEY,
    OrderID         BIGINT NOT NULL,
    PaymentDate     DATETIME2(0) NOT NULL CONSTRAINT DF_Payments_Date DEFAULT (SYSDATETIME()),
    PaymentMethod   VARCHAR(20) NOT NULL,
    PaymentStatus   VARCHAR(20) NOT NULL CONSTRAINT DF_Payments_Status DEFAULT ('SUCCESS'),
    Amount          DECIMAL(12,2) NOT NULL,
    TransactionRef  VARCHAR(100) NULL,
    CONSTRAINT FK_Payments_Orders FOREIGN KEY (OrderID) REFERENCES dbo.RestaurantOrders(OrderID),
    CONSTRAINT CK_Payments_Method CHECK (PaymentMethod IN ('CASH','CARD','UPI','WALLET','ONLINE')),
    CONSTRAINT CK_Payments_Status CHECK (PaymentStatus IN ('PENDING','SUCCESS','FAILED','REFUNDED')),
    CONSTRAINT CK_Payments_Amount CHECK (Amount > 0),
    CONSTRAINT UQ_Payments_TransactionRef UNIQUE (TransactionRef)
);
GO

CREATE TABLE dbo.InventoryItems
(
    InventoryItemID INT IDENTITY(1,1) CONSTRAINT PK_InventoryItems PRIMARY KEY,
    ItemName         NVARCHAR(120) NOT NULL CONSTRAINT UQ_InventoryItems_Name UNIQUE,
    UnitOfMeasure    VARCHAR(20) NOT NULL,
    ReorderLevel     DECIMAL(12,3) NOT NULL CONSTRAINT DF_Inventory_Reorder DEFAULT (0),
    IsActive         BIT NOT NULL CONSTRAINT DF_Inventory_IsActive DEFAULT (1),
    CONSTRAINT CK_Inventory_Reorder CHECK (ReorderLevel >= 0)
);
GO

CREATE TABLE dbo.BranchInventory
(
    BranchID         INT NOT NULL,
    InventoryItemID  INT NOT NULL,
    QuantityOnHand   DECIMAL(12,3) NOT NULL CONSTRAINT DF_BranchInventory_Qty DEFAULT (0),
    LastUpdated      DATETIME2(0) NOT NULL CONSTRAINT DF_BranchInventory_Updated DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_BranchInventory PRIMARY KEY (BranchID, InventoryItemID),
    CONSTRAINT FK_BranchInventory_Branch FOREIGN KEY (BranchID) REFERENCES dbo.Branches(BranchID),
    CONSTRAINT FK_BranchInventory_Item FOREIGN KEY (InventoryItemID) REFERENCES dbo.InventoryItems(InventoryItemID),
    CONSTRAINT CK_BranchInventory_Qty CHECK (QuantityOnHand >= 0)
);
GO

CREATE TABLE dbo.InventoryTransactions
(
    InventoryTransactionID BIGINT IDENTITY(1,1) CONSTRAINT PK_InventoryTransactions PRIMARY KEY,
    BranchID                INT NOT NULL,
    InventoryItemID         INT NOT NULL,
    TransactionType         VARCHAR(20) NOT NULL,
    QuantityChange          DECIMAL(12,3) NOT NULL,
    ReferenceText           NVARCHAR(150) NULL,
    TransactionDate         DATETIME2(0) NOT NULL CONSTRAINT DF_InventoryTransactions_Date DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_InvTrans_Branch FOREIGN KEY (BranchID) REFERENCES dbo.Branches(BranchID),
    CONSTRAINT FK_InvTrans_Item FOREIGN KEY (InventoryItemID) REFERENCES dbo.InventoryItems(InventoryItemID),
    CONSTRAINT CK_InvTrans_Type CHECK (TransactionType IN ('RECEIPT','USAGE','ADJUSTMENT','WASTE')),
    CONSTRAINT CK_InvTrans_Quantity CHECK (QuantityChange <> 0)
);
GO

CREATE TABLE dbo.OrderStatusHistory
(
    StatusHistoryID BIGINT IDENTITY(1,1) CONSTRAINT PK_OrderStatusHistory PRIMARY KEY,
    OrderID         BIGINT NOT NULL,
    OldStatus       VARCHAR(20) NULL,
    NewStatus       VARCHAR(20) NOT NULL,
    ChangedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_StatusHistory_ChangedAt DEFAULT (SYSDATETIME()),
    ChangedBy       NVARCHAR(128) NOT NULL CONSTRAINT DF_StatusHistory_ChangedBy DEFAULT (SUSER_SNAME()),
    CONSTRAINT FK_StatusHistory_Orders FOREIGN KEY (OrderID) REFERENCES dbo.RestaurantOrders(OrderID)
);
GO

CREATE TABLE dbo.OrderAudit
(
    AuditID       BIGINT IDENTITY(1,1) CONSTRAINT PK_OrderAudit PRIMARY KEY,
    OrderID       BIGINT NOT NULL,
    OldStatus     VARCHAR(20) NULL,
    NewStatus     VARCHAR(20) NULL,
    AuditAction   VARCHAR(30) NOT NULL,
    ChangedAt     DATETIME2(0) NOT NULL CONSTRAINT DF_OrderAudit_ChangedAt DEFAULT (SYSDATETIME()),
    ChangedBy     NVARCHAR(128) NOT NULL CONSTRAINT DF_OrderAudit_ChangedBy DEFAULT (SUSER_SNAME())
);
GO

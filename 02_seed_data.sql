USE RestaurantOrderManagement;
GO

INSERT dbo.Branches (BranchName, Phone, Email, AddressLine, City, StateProvince, PostalCode)
VALUES
(N'Central Kitchen', '02040001001', 'central@example.test', N'FC Road', N'Pune', N'Maharashtra', '411004'),
(N'Riverside Branch', '02040001002', 'riverside@example.test', N'Koregaon Park', N'Pune', N'Maharashtra', '411001'),
(N'West End Branch', '02040001003', 'westend@example.test', N'Baner Road', N'Pune', N'Maharashtra', '411045');

INSERT dbo.Employees (BranchID, FirstName, LastName, JobTitle, Email, Phone, HireDate)
VALUES
(1, N'Aarav', N'Sharma', N'Manager', 'aarav@example.test', '9000000001', '2022-04-01'),
(1, N'Mira', N'Patil', N'Cashier', 'mira@example.test', '9000000002', '2023-01-15'),
(2, N'Kabir', N'Deshmukh', N'Manager', 'kabir@example.test', '9000000003', '2021-08-10'),
(3, N'Sana', N'Kulkarni', N'Manager', 'sana@example.test', '9000000004', '2023-06-20');

INSERT dbo.Customers (FirstName, LastName, Email, Phone)
VALUES
(N'Riya', N'Joshi', 'riya@example.test', '9100000001'),
(N'Aditya', N'Rao', 'aditya@example.test', '9100000002'),
(N'Neha', N'Kapoor', 'neha@example.test', '9100000003'),
(N'Ved', N'Mehta', 'ved@example.test', '9100000004'),
(N'Anaya', N'Pawar', 'anaya@example.test', '9100000005'),
(N'Om', N'Kulkarni', 'om@example.test', '9100000006');

INSERT dbo.Categories (CategoryName, Description)
VALUES
(N'Starters', N'Small plates and appetizers'),
(N'Main Course', N'Main dishes'),
(N'Beverages', N'Hot and cold drinks'),
(N'Desserts', N'Sweets and desserts');

INSERT dbo.MenuItems (CategoryID, ItemName, Description, UnitPrice, IsAvailable, IsStockTracked)
VALUES
(1, N'Paneer Tikka', N'Grilled marinated paneer', 240.00, 1, 0),
(1, N'Veg Spring Rolls', N'Crispy vegetable rolls', 180.00, 1, 0),
(2, N'Veg Biryani', N'Fragrant rice with vegetables', 280.00, 1, 0),
(2, N'Paneer Butter Masala', N'Paneer in tomato butter gravy', 320.00, 1, 0),
(2, N'Chicken Biryani', N'Spiced chicken rice', 360.00, 1, 0),
(3, N'Masala Chai', N'Indian spiced tea', 60.00, 1, 0),
(3, N'Fresh Lime Soda', N'Sweet or salted lime soda', 90.00, 1, 0),
(4, N'Gulab Jamun', N'Traditional milk-solid dessert', 100.00, 1, 0),
(4, N'Brownie', N'Chocolate brownie', 150.00, 1, 0);

INSERT dbo.InventoryItems (ItemName, UnitOfMeasure, ReorderLevel)
VALUES
(N'Paneer', 'KG', 5),
(N'Basmati Rice', 'KG', 10),
(N'Cooking Oil', 'LITRE', 8),
(N'Soft Drink Syrup', 'LITRE', 3);

INSERT dbo.BranchInventory (BranchID, InventoryItemID, QuantityOnHand)
VALUES
(1,1,18),(1,2,40),(1,3,22),(1,4,6),
(2,1,4),(2,2,8),(2,3,5),(2,4,2),
(3,1,12),(3,2,16),(3,3,10),(3,4,4);

INSERT dbo.RestaurantOrders
(BranchID, CustomerID, EmployeeID, OrderDate, OrderType, OrderStatus, Subtotal, DiscountAmount, TaxAmount, DeliveryFee, TotalAmount, Notes)
VALUES
(1,1,2,'2025-01-05T12:15:00','DINE_IN','COMPLETED',520,20,25,0,525,N'Window table'),
(1,2,2,'2025-01-05T19:30:00','TAKEAWAY','COMPLETED',360,0,18,0,378,NULL),
(2,3,3,'2025-01-06T13:05:00','DELIVERY','COMPLETED',420,20,20,40,460,N'Call on arrival'),
(2,4,3,'2025-01-07T20:10:00','DINE_IN','CANCELLED',280,0,14,0,294,N'Customer cancelled'),
(3,5,4,'2025-02-02T18:40:00','TAKEAWAY','COMPLETED',510,10,25,0,525,NULL),
(1,1,2,'2025-02-10T11:20:00','DELIVERY','COMPLETED',330,0,16.5,30,376.5,NULL),
(2,6,3,'2025-02-11T20:15:00','DINE_IN','PREPARING',600,50,27.5,0,577.5,NULL),
(3,2,4,'2025-03-01T14:00:00','DINE_IN','COMPLETED',240,0,12,0,252,NULL);

INSERT dbo.OrderItems (OrderID, MenuItemID, Quantity, UnitPrice, SpecialInstructions)
VALUES
(1,1,1,240,NULL),(1,3,1,280,NULL),
(2,5,1,360,N'Medium spice'),
(3,4,1,320,NULL),(3,6,1,60,NULL),(3,7,1,40,NULL),
(4,3,1,280,NULL),
(5,4,1,320,NULL),(5,8,1,100,NULL),(5,6,1,60,NULL),
(6,2,1,180,NULL),(6,9,1,150,NULL),
(7,3,1,280,NULL),(7,4,1,320,NULL),
(8,1,1,240,NULL);

INSERT dbo.Payments (OrderID, PaymentDate, PaymentMethod, PaymentStatus, Amount, TransactionRef)
VALUES
(1,'2025-01-05T12:35:00','UPI','SUCCESS',525,'TXN-DEMO-0001'),
(2,'2025-01-05T19:45:00','CARD','SUCCESS',378,'TXN-DEMO-0002'),
(3,'2025-01-06T13:40:00','ONLINE','SUCCESS',460,'TXN-DEMO-0003'),
(5,'2025-02-02T19:00:00','CASH','SUCCESS',525,'TXN-DEMO-0005'),
(6,'2025-02-10T11:45:00','UPI','SUCCESS',376.5,'TXN-DEMO-0006'),
(8,'2025-03-01T14:20:00','CASH','SUCCESS',252,'TXN-DEMO-0008');

INSERT dbo.OrderStatusHistory (OrderID, OldStatus, NewStatus)
SELECT OrderID, NULL, OrderStatus
FROM dbo.RestaurantOrders;
GO

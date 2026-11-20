/*
  Run this script using an account with CREATE DATABASE permission.
  If the database already exists, it will not be recreated.
*/
IF DB_ID(N'RestaurantOrderManagement') IS NULL
BEGIN
    CREATE DATABASE RestaurantOrderManagement;
END;
GO

USE RestaurantOrderManagement;
GO

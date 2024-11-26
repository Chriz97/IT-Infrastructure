-- SQL Basics Script
-- This script covers essential SQL commands for working with a relational database.

-- 1. CREATE DATABASE
-- Creates a new database.
CREATE DATABASE ExampleDB;

-- Use the created database
USE ExampleDB;

-- 2. CREATE TABLE
-- Creates a new table with specified columns and data types.
CREATE TABLE Employees (
    EmployeeID INT PRIMARY KEY AUTO_INCREMENT,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Department VARCHAR(50),
    Salary DECIMAL(10, 2),
    HireDate DATE
);

-- 3. INSERT INTO
-- Inserts data into a table.
INSERT INTO Employees (FirstName, LastName, Department, Salary, HireDate)
VALUES
('John', 'Doe', 'HR', 50000, '2023-01-15'),
('Jane', 'Smith', 'Engineering', 75000, '2022-06-10'),
('Michael', 'Brown', 'Marketing', 60000, '2021-11-25');

-- 4. SELECT
-- Retrieves data from a table.
-- Retrieve all columns and rows.
SELECT * FROM Employees;

-- Retrieve specific columns.
SELECT FirstName, LastName, Salary FROM Employees;

-- Retrieve rows with a condition.
SELECT * FROM Employees WHERE Department = 'Engineering';

-- 5. UPDATE
-- Updates existing records in a table.
-- Example: Increase salary for all employees in the HR department.
UPDATE Employees
SET Salary = Salary * 1.10
WHERE Department = 'HR';

-- 6. DELETE
-- Deletes rows from a table.
-- Example: Remove an employee by ID.
DELETE FROM Employees WHERE EmployeeID = 3;

-- 7. ALTER TABLE
-- Modify the structure of an existing table.
-- Add a new column.
ALTER TABLE Employees ADD Email VARCHAR(100);

-- Drop an existing column.
ALTER TABLE Employees DROP COLUMN Email;

-- 8. DROP TABLE
-- Deletes the entire table structure and data.
DROP TABLE Employees;

-- 9. DROP DATABASE
-- Deletes the database entirely.
DROP DATABASE ExampleDB;

-- 10. Additional Commands

-- COUNT: Count rows in a table.
SELECT COUNT(*) AS TotalEmployees FROM Employees;

-- ORDER BY: Sort results by a column (ascending or descending).
SELECT * FROM Employees ORDER BY Salary DESC;

-- GROUP BY: Group data and apply aggregate functions.
SELECT Department, AVG(Salary) AS AvgSalary
FROM Employees
GROUP BY Department;

-- LIMIT: Restrict the number of rows returned.
SELECT * FROM Employees LIMIT 2;

-- End of SQL Basics Script

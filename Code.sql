-- create seperate database for the project by the name Hospitality
CREATE DATABASE Hospitality;

-- CREATING REQUIRED TABLES
--Users
CREATE TABLE Users (
    user_id INT PRIMARY KEY IDENTITY,
    name NVARCHAR(100),
    email NVARCHAR(100) UNIQUE,
    password NVARCHAR(100),
    user_type NVARCHAR(50) CHECK (user_type IN ('customer', 'admin'))
);

-- Hotels
CREATE TABLE Hotels (
    hotel_id INT PRIMARY KEY IDENTITY,
    name NVARCHAR(100),
    location NVARCHAR(100),
    star_rating INT CHECK (star_rating BETWEEN 1 AND 5)
);

-- Rooms
CREATE TABLE Rooms (
    room_id INT PRIMARY KEY IDENTITY,
    hotel_id INT,
    room_type NVARCHAR(50),
    capacity INT,
    price DECIMAL(10,2),
    is_active BIT DEFAULT 1,
    FOREIGN KEY (hotel_id) REFERENCES Hotels(hotel_id)
);

-- Reservations
CREATE TABLE Reservations (
    res_id INT PRIMARY KEY IDENTITY,
    user_id INT,
    room_id INT,
    check_in_date DATE,
    check_out_date DATE,
    status NVARCHAR(20) CHECK (status IN ('booked', 'cancelled', 'checked_in', 'checked_out')),
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (room_id) REFERENCES Rooms(room_id)
);

-- Billing
CREATE TABLE Billing (
    bill_id INT PRIMARY KEY IDENTITY,
    res_id INT,
    amount DECIMAL(10,2),
    payment_method NVARCHAR(50),
    bill_date DATE,
    FOREIGN KEY (res_id) REFERENCES Reservations(res_id)
);

-- Check in / out
CREATE TABLE CheckInOut (
    log_id INT PRIMARY KEY IDENTITY,
    res_id INT,
    checkin_time DATETIME,
    checkout_time DATETIME,
    FOREIGN KEY (res_id) REFERENCES Reservations(res_id)
);

-- CREATING THE STORED PROCEDURES
-- User Login
CREATE PROCEDURE sp_login_user
    @Email NVARCHAR(100),
    @Password NVARCHAR(100)
AS
BEGIN
    SELECT * FROM Users WHERE email = @Email AND password = @Password;
END;

-- Hotel details
CREATE PROCEDURE sp_register_hotel
    @Name NVARCHAR(100),
    @Location NVARCHAR(100),
    @StarRating INT
AS
BEGIN
    INSERT INTO Hotels (name, location, star_rating)
    VALUES (@Name, @Location, @StarRating);
END;

-- Room Details
CREATE PROCEDURE sp_register_room
    @HotelID INT,
    @RoomType NVARCHAR(50),
    @Capacity INT,
    @Price DECIMAL(10,2)
AS
BEGIN
    INSERT INTO Rooms (hotel_id, room_type, capacity, price)
    VALUES (@HotelID, @RoomType, @Capacity, @Price);
END;

-- Check room availability
CREATE PROCEDURE sp_check_room_availability
    @room_id INT,
    @check_in_date DATE,
    @check_out_date DATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM Reservations
        WHERE room_id = @room_id
          AND status = 'booked'
          AND (
              (@check_in_date BETWEEN check_in_date AND check_out_date)
              OR (@check_out_date BETWEEN check_in_date AND check_out_date)
              OR (check_in_date BETWEEN @check_in_date AND @check_out_date)
              OR (check_out_date BETWEEN @check_in_date AND @check_out_date)
          )
    )
        SELECT 'Not Available' AS AvailabilityStatus;
    ELSE
        SELECT 'Available' AS AvailabilityStatus;
END;

-- Make Reservation

CREATE PROCEDURE sp_make_reservation
    @user_id INT,
    @room_id INT,
    @check_in_date DATE,
    @check_out_date DATE
AS
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM Reservations
        WHERE room_id = @room_id
          AND status = 'booked'
          AND (
              (@check_in_date BETWEEN check_in_date AND check_out_date)
              OR (@check_out_date BETWEEN check_in_date AND check_out_date)
              OR (check_in_date BETWEEN @check_in_date AND @check_out_date)
              OR (check_out_date BETWEEN @check_in_date AND @check_out_date)
          )
    )
    BEGIN
        INSERT INTO Reservations (user_id, room_id, check_in_date, check_out_date, status)
        VALUES (@user_id, @room_id, @check_in_date, @check_out_date, 'booked');
    END
    ELSE
    BEGIN
        SELECT 'Room Not Available for selected dates.' AS ErrorMessage;
    END
END;

-- Bill Genertaion
CREATE PROCEDURE sp_generate_bill
    @res_id INT,
    @payment_method NVARCHAR(50)
AS
BEGIN
    DECLARE @days INT, @rate DECIMAL(10,2), @total DECIMAL(10,2);

    SELECT @days = DATEDIFF(DAY, check_in_date, check_out_date)
    FROM Reservations WHERE res_id = @res_id;

    SELECT @rate = price FROM Rooms
    WHERE room_id = (SELECT room_id FROM Reservations WHERE res_id = @res_id);

    SET @total = @days * @rate;

    INSERT INTO Billing (res_id, amount, payment_method, bill_date)
    VALUES (@res_id, @total, @payment_method, GETDATE());
END;

-- Checkin
CREATE PROCEDURE sp_checkin_guest
    @res_id INT
AS
BEGIN
    UPDATE Reservations SET status = 'checked_in' WHERE res_id = @res_id;
    INSERT INTO CheckInOut (res_id, checkin_time) VALUES (@res_id, GETDATE());
END;

--Check out
CREATE PROCEDURE sp_checkout_guest
    @res_id INT
AS
BEGIN
    UPDATE Reservations SET status = 'checked_out' WHERE res_id = @res_id;
    UPDATE CheckInOut SET checkout_time = GETDATE() WHERE res_id = @res_id;
END;

--INPUT DATA INTO TABLES THROUGH PROCEDURES 
-- Users
INSERT INTO Users (name, email, password, user_type)
VALUES ('Himanshu Gupta', 'himanshu@example.com', 'pass123', 'customer'),
       ('Admin User', 'admin@example.com', 'adminpass', 'admin');

-- Hotels
EXEC sp_register_hotel 'Hotel Royal', 'Jaipur', 4;
EXEC sp_register_hotel 'Green Valley', 'Shimla', 5;

-- Rooms
EXEC sp_register_room 1, 'Deluxe', 2, 4000;
EXEC sp_register_room 1, 'Standard', 2, 2500;
EXEC sp_register_room 2, 'Suite', 4, 6000;
EXEC sp_register_room 2, 'Standard', 2, 3000;

-- TEST CASES
-- Reservation test case
EXEC sp_make_reservation 1, 1, '2025-07-10', '2025-07-14'; -- Should succeed
EXEC sp_make_reservation 1, 1, '2025-07-11', '2025-07-12'; -- Should fail (overlap)

-- Availability check
EXEC sp_check_room_availability 1, '2025-07-10', '2025-07-13'; -- Not Available
EXEC sp_check_room_availability 3, '2025-07-14', '2025-07-15'; -- Available

-- Bill
EXEC sp_generate_bill 1, 'UPI';

-- Check in/out
EXEC sp_checkin_guest 1;
EXEC sp_checkout_guest 1;


-- Displaying table data

SELECT * FROM Users;
SELECT * FROM Hotels;
SELECT * FROM Rooms;
SELECT * FROM Reservations;
SELECT * FROM Billing;
SELECT * FROM CheckInOut;
SELECT * FROM Reservations;

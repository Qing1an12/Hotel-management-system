-- Create schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS "hotel chains";

-- Set the search path
SET search_path TO "hotel chains", public;

-- Create sequences for auto-incrementing IDs
CREATE SEQUENCE IF NOT EXISTS customer_id_seq;
CREATE SEQUENCE IF NOT EXISTS employee_id_seq;
CREATE SEQUENCE IF NOT EXISTS booking_id_seq;
CREATE SEQUENCE IF NOT EXISTS renting_id_seq;
CREATE SEQUENCE IF NOT EXISTS room_id_seq;
CREATE SEQUENCE IF NOT EXISTS hotel_id_seq;
CREATE SEQUENCE IF NOT EXISTS chain_id_seq;

-- Create tables
CREATE TABLE IF NOT EXISTS hotelchains (
    chainid INTEGER PRIMARY KEY DEFAULT nextval('chain_id_seq'),
    name VARCHAR(100) NOT NULL,
    numhotels INTEGER,
    email VARCHAR(100),
    phone VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS hotels (
    hotelid INTEGER PRIMARY KEY DEFAULT nextval('hotel_id_seq'),
    chainid INTEGER REFERENCES hotelchains(chainid),
    category INTEGER CHECK (category BETWEEN 1 AND 5),
    numrooms INTEGER,
    address VARCHAR(200),
    email VARCHAR(100),
    phone VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS rooms (
    roomid INTEGER PRIMARY KEY DEFAULT nextval('room_id_seq'),
    hotelid INTEGER REFERENCES hotels(hotelid),
    price DECIMAL(10,2),
    capacity INTEGER,
    view VARCHAR(50),
    extendable BOOLEAN,
    problems TEXT[]
);

CREATE TABLE IF NOT EXISTS customers (
    customerid INTEGER PRIMARY KEY DEFAULT nextval('customer_id_seq'),
    firstname VARCHAR(50) NOT NULL,
    lastname VARCHAR(50) NOT NULL,
    address VARCHAR(200) NOT NULL,
    registration_date DATE DEFAULT CURRENT_DATE
);

CREATE TABLE IF NOT EXISTS employees (
    employeeid INTEGER PRIMARY KEY DEFAULT nextval('employee_id_seq'),
    hotelid INTEGER REFERENCES hotels(hotelid),
    firstname VARCHAR(50) NOT NULL,
    lastname VARCHAR(50) NOT NULL,
    address VARCHAR(200) NOT NULL,
    role VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS bookings (
    bookingid INTEGER PRIMARY KEY DEFAULT nextval('booking_id_seq'),
    roomid INTEGER REFERENCES rooms(roomid),
    hotelid INTEGER REFERENCES hotels(hotelid),
    customerid INTEGER REFERENCES customers(customerid),
    startdate DATE NOT NULL,
    enddate DATE NOT NULL,
    CONSTRAINT valid_booking_dates CHECK (enddate > startdate)
);

CREATE TABLE IF NOT EXISTS rentings (
    rentingid INTEGER PRIMARY KEY DEFAULT nextval('renting_id_seq'),
    bookingid INTEGER REFERENCES bookings(bookingid),
    roomid INTEGER REFERENCES rooms(roomid),
    hotelid INTEGER REFERENCES hotels(hotelid),
    customerid INTEGER REFERENCES customers(customerid),
    employeeid INTEGER REFERENCES employees(employeeid),
    startdate DATE NOT NULL,
    enddate DATE NOT NULL,
    CONSTRAINT valid_renting_dates CHECK (enddate > startdate)
);

-- Create views
CREATE OR REPLACE VIEW room_capacity_view AS
SELECT h.chainid, h.hotelid, COUNT(*) as total_rooms,
    SUM(CASE WHEN r.capacity >= 1 THEN 1 ELSE 0 END) as single_rooms,
    SUM(CASE WHEN r.capacity >= 2 THEN 1 ELSE 0 END) as double_rooms,
    SUM(CASE WHEN r.capacity >= 4 THEN 1 ELSE 0 END) as family_rooms
FROM hotels h
LEFT JOIN rooms r ON h.hotelid = r.hotelid
GROUP BY h.chainid, h.hotelid;

CREATE OR REPLACE VIEW room_area_view AS
SELECT h.chainid, h.hotelid, h.address as hotel_address,
    COUNT(*) as total_rooms,
    STRING_AGG(DISTINCT r.view, ', ') as available_views
FROM hotels h
LEFT JOIN rooms r ON h.hotelid = r.hotelid
GROUP BY h.chainid, h.hotelid, h.address;

-- Drop schema if exists
DROP SCHEMA IF EXISTS "hotel chains" CASCADE;

-- Create schema
CREATE SCHEMA "hotel chains";

-- Create sequences
CREATE SEQUENCE "hotel chains".customer_id_seq;
CREATE SEQUENCE "hotel chains".employee_id_seq;
CREATE SEQUENCE "hotel chains".booking_id_seq;
CREATE SEQUENCE "hotel chains".renting_id_seq;
CREATE SEQUENCE "hotel chains".room_id_seq;
CREATE SEQUENCE "hotel chains".hotel_id_seq;
CREATE SEQUENCE "hotel chains".chain_id_seq;

-- Create tables
CREATE TABLE "hotel chains".hotelchains (
    chainid INTEGER PRIMARY KEY DEFAULT nextval('"hotel chains".chain_id_seq'),
    cname VARCHAR(100) NOT NULL,
    num_of_hotels INTEGER,
    caddress VARCHAR(200),
    rating INTEGER,
    cemail VARCHAR(100),
    cphone VARCHAR(20)
);

CREATE TABLE "hotel chains".hotels (
    hotelid INTEGER PRIMARY KEY DEFAULT nextval('"hotel chains".hotel_id_seq'),
    chainid INTEGER REFERENCES "hotel chains".hotelchains(chainid),
    haddress VARCHAR(200),
    hname VARCHAR(100),
    num_of_rooms INTEGER,
    hemail VARCHAR(100),
    hphone VARCHAR(20),
    managerid INTEGER
);

CREATE TABLE "hotel chains".rooms (
    roomid INTEGER,
    hotelid INTEGER REFERENCES "hotel chains".hotels(hotelid),
    price DECIMAL(10,2),
    view VARCHAR(50),
    amenities TEXT[],
    problems TEXT[],
    extendable BOOLEAN,
    capacity INTEGER,
    PRIMARY KEY (roomid, hotelid)
);

CREATE TABLE "hotel chains".customers (
    customerid INTEGER PRIMARY KEY DEFAULT nextval('"hotel chains".customer_id_seq'),
    firstname VARCHAR(100),
    lastname VARCHAR(100),
    address VARCHAR(200),
    dateofregistration DATE DEFAULT CURRENT_DATE
);

CREATE TABLE "hotel chains".employees (
    employeeid INTEGER PRIMARY KEY DEFAULT nextval('"hotel chains".employee_id_seq'),
    efirstname VARCHAR(100),
    elastname VARCHAR(100),
    ssnsin INTEGER,
    eaddress VARCHAR(200),
    hotelid INTEGER REFERENCES "hotel chains".hotels(hotelid),
    erole VARCHAR(50)
);

ALTER TABLE "hotel chains".hotels 
    ADD CONSTRAINT fk_manager_id 
    FOREIGN KEY (managerid) 
    REFERENCES "hotel chains".employees(employeeid);

CREATE TABLE "hotel chains".bookings (
    bookingid INTEGER PRIMARY KEY DEFAULT nextval('"hotel chains".booking_id_seq'),
    roomid INTEGER,
    hotelid INTEGER,
    customerid INTEGER REFERENCES "hotel chains".customers(customerid),
    startdate DATE,
    enddate DATE,
    status VARCHAR(20) DEFAULT 'Booked',
    FOREIGN KEY (roomid, hotelid) REFERENCES "hotel chains".rooms(roomid, hotelid)
);

CREATE TABLE "hotel chains".rentings (
    rentingid INTEGER PRIMARY KEY DEFAULT nextval('"hotel chains".renting_id_seq'),
    roomid INTEGER,
    hotelid INTEGER,
    customerid INTEGER REFERENCES "hotel chains".customers(customerid),
    employeeid INTEGER REFERENCES "hotel chains".employees(employeeid),
    startdate DATE,
    enddate DATE,
    status VARCHAR(20) DEFAULT 'Active',
    FOREIGN KEY (roomid, hotelid) REFERENCES "hotel chains".rooms(roomid, hotelid)
);

-- Sample data
INSERT INTO "hotel chains".hotelchains (chainid, cname, num_of_hotels, caddress, rating, cemail, cphone) VALUES
(1, 'Crabby Patty Resorts', 5, '2432 Bikini Bottom', 5, 'squid@crabbypatty.com', '1234567'),
(2, 'Krusty Krab Hotels', 3, '124 Bikini Bottom', 4, 'krusty@krab.com', '7654321'),
(3, 'Olympian Stays', 4, '1 Mount Olympus', 5, 'zeus@olympus.com', '8888888'),
(4, 'Mythical Inns', 3, '42 Legends Way', 4, 'myths@legends.com', '9999999');

INSERT INTO "hotel chains".hotels (hotelid, chainid, haddress, hname, num_of_rooms, hemail, hphone) VALUES
(1, 1, '432 Pinapple St', 'Sponge Hotel', 5, 'sponge@bobhotels.com', '3253252'),
(2, 1, '433 Rock St', 'Patrick Hotel', 4, 'pat@starhotels.com', '3253253'),
(3, 2, '434 Anchor Way', 'Krusty Inn', 5, 'krusty@inn.com', '3253254'),
(4, 2, '435 Shell St', 'Shell Shack Lodge', 5, 'info@shellshack.com', '3253255'),
(5, 3, '13 Olympus Ave', 'Zeus Palace', 5, 'stay@zeus.com', '3253256'),
(6, 3, '14 Olympus Ave', 'Athena Lodge', 5, 'athena@lodge.com', '3253257'),
(7, 3, '15 Olympus Ave', 'Poseidon Resort', 5, 'waves@poseidon.com', '3253258'),
(8, 4, '22 Myth St', 'Phoenix Inn', 5, 'rise@phoenix.com', '3253259'),
(9, 4, '23 Myth St', 'Dragon Lodge', 5, 'fire@dragon.com', '3253260'),
(10, 4, '24 Myth St', 'Griffin Hotel', 5, 'stay@griffin.com', '3253261');

INSERT INTO "hotel chains".rooms (roomid, hotelid, price, view, amenities, problems, extendable, capacity) VALUES
(1, 1, 100.0, 'sea', ARRAY['Wifi','TV','free coffee'], ARRAY['stained curtains'], true, 1),
(2, 1, 150.0, 'mountain', ARRAY['Wifi','TV','Minibar'], ARRAY['Uneven table'], true, 2),
(3, 1, 70.0, 'mountain', ARRAY['Wifi','TV'], ARRAY['cracked bedboard','broken lamp'], false, 1),
(4, 1, 270.0, 'mountain', ARRAY['Wifi','TV','Kitchenette','disability accomodation'], ARRAY[]::text[], false, 4),
(5, 1, 200.0, 'sea', ARRAY['WiFi','TV','Futon'], ARRAY['broken light'], false, 3),
(6, 2, 300.0, 'mountain', ARRAY['Wifi','TV','Futon','Minibar','kitchenette'], ARRAY['Damaged chairs'], false, 5),
(7, 2, 150.0, 'mountain', ARRAY['Wifi','TV'], ARRAY[]::text[], true, 2),
(8, 2, 70.0, 'sea', ARRAY['Wifi','TV'], ARRAY['cracked bedboard','broken lamp'], false, 1),
(9, 2, 300.0, 'mountain', ARRAY['Wifi','TV','Kitchenette','Bathtub'], ARRAY['Damaged floorboard','damaged couch cushion'], true, 4),
(10, 2, 200.0, 'mountain', ARRAY['WiFi','TV','Futon'], ARRAY['broken light'], false, 3),
(11, 3, 70.0, 'sea', ARRAY['Wifi'], ARRAY['Finicky showerhead'], false, 1),
(12, 3, 200.0, 'mountain', ARRAY['Wifi','TV'], ARRAY[]::text[], true, 2),
(13, 3, 200.0, 'sea', ARRAY['Wifi','TV','bathtub'], ARRAY['sticky doorhandle'], true, 2),
(14, 3, 220.0, 'mountain', ARRAY['Wifi','TV','Kitchenette'], ARRAY['flickering lights'], true, 3),
(15, 3, 200.0, 'sea', ARRAY['WiFi','TV','Futon'], ARRAY['broken light'], false, 3),
(16, 4, 70.0, 'sea', ARRAY['Wifi'], ARRAY[]::text[], false, 1),
(17, 4, 200.0, 'mountain', ARRAY['Wifi','TV'], ARRAY[]::text[], true, 2),
(18, 4, 220.0, 'mountain', ARRAY['Wifi','TV','Minibar'], ARRAY['sticky doorhandle'], true, 2),
(19, 4, 240.0, 'mountain', ARRAY['Wifi','TV','Kitchenette'], ARRAY[]::text[], true, 4),
(20, 4, 300.0, 'sea', ARRAY['WiFi','TV','Futon','kitchenette','bathtub'], ARRAY[]::text[], false, 6),
(21, 5, 100.0, 'mountain', ARRAY['Wifi','Gym'], ARRAY[]::text[], true, 1),
(22, 5, 150.0, 'mountain', ARRAY['Wifi','TV','Gym'], ARRAY[]::text[], true, 2),
(23, 5, 220.0, 'sea', ARRAY['Wifi','TV','Minibar'], ARRAY['sticky doorhandle'], false, 3),
(24, 5, 240.0, 'sea', ARRAY['Wifi','TV','Kitchenette'], ARRAY[]::text[], true, 4),
(25, 5, 370.0, 'sea', ARRAY['WiFi','TV','Futon','kitchenette','bathtub','Gym'], ARRAY[]::text[], false, 6),
(26, 6, 100.0, 'mountain', ARRAY['Wifi','Gym'], ARRAY[]::text[], true, 1),
(27, 6, 150.0, 'mountain', ARRAY['Wifi','TV','Gym'], ARRAY['broken clothing hangers'], true, 2),
(28, 6, 220.0, 'sea', ARRAY['Wifi','TV','Minibar'], ARRAY['broken lamp'], false, 3),
(29, 6, 240.0, 'sea', ARRAY['Wifi','TV','Kitchenette'], ARRAY[]::text[], true, 4),
(30, 6, 370.0, 'sea', ARRAY['WiFi','TV','Futon','kitchenette','bathtub','Gym'], ARRAY[]::text[], false, 6),
(31, 7, 100.0, 'mountain', ARRAY['Wifi','Gym'], ARRAY[]::text[], true, 1),
(32, 7, 150.0, 'mountain', ARRAY['Wifi','TV','Gym'], ARRAY['broken clothing hangers'], true, 2),
(33, 7, 220.0, 'sea', ARRAY['Wifi','TV','Minibar'], ARRAY['broken lamp'], false, 3),
(34, 7, 240.0, 'sea', ARRAY['Wifi','TV','Kitchenette'], ARRAY[]::text[], true, 4),
(35, 7, 370.0, 'sea', ARRAY['WiFi','TV','Futon','kitchenette','bathtub','Gym'], ARRAY[]::text[], false, 6),
(36, 8, 100.0, 'mountain', ARRAY['Wifi','Gym'], ARRAY[]::text[], true, 1),
(37, 8, 150.0, 'mountain', ARRAY['Wifi','TV','Gym'], ARRAY['broken clothing hangers'], true, 2),
(38, 8, 220.0, 'sea', ARRAY['Wifi','TV','Minibar'], ARRAY['broken lamp'], false, 3),
(39, 8, 240.0, 'sea', ARRAY['Wifi','TV','Kitchenette'], ARRAY[]::text[], true, 4),
(40, 8, 370.0, 'sea', ARRAY['WiFi','TV','Futon','kitchenette','bathtub','Gym'], ARRAY[]::text[], false, 6),
(41, 9, 100.0, 'mountain', ARRAY['Wifi','Gym'], ARRAY[]::text[], true, 1),
(42, 9, 150.0, 'mountain', ARRAY['Wifi','TV','Gym'], ARRAY['broken clothing hangers'], true, 2),
(43, 9, 220.0, 'sea', ARRAY['Wifi','TV','Minibar'], ARRAY['broken lamp'], false, 3),
(44, 9, 240.0, 'sea', ARRAY['Wifi','TV','Kitchenette'], ARRAY[]::text[], true, 4),
(45, 9, 370.0, 'sea', ARRAY['WiFi','TV','Futon','kitchenette','bathtub','Gym'], ARRAY[]::text[], false, 6),
(46, 10, 100.0, 'mountain', ARRAY['Wifi','Gym'], ARRAY[]::text[], true, 1),
(47, 10, 150.0, 'mountain', ARRAY['Wifi','TV','Gym'], ARRAY['broken clothing hangers'], true, 2),
(48, 10, 220.0, 'sea', ARRAY['Wifi','TV','Minibar'], ARRAY['broken lamp'], false, 3),
(49, 10, 240.0, 'sea', ARRAY['Wifi','TV','Kitchenette'], ARRAY[]::text[], true, 4),
(50, 10, 370.0, 'sea', ARRAY['WiFi','TV','Futon','kitchenette','bathtub','Gym'], ARRAY[]::text[], false, 6);

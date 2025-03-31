--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

-- Started on 2025-03-31 18:41:48

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 6 (class 2615 OID 16427)
-- Name: hotel chains; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA "hotel chains";


ALTER SCHEMA "hotel chains" OWNER TO postgres;

--
-- TOC entry 228 (class 1255 OID 17755)
-- Name: auto_checkout(); Type: FUNCTION; Schema: hotel chains; Owner: postgres
--

CREATE FUNCTION "hotel chains".auto_checkout() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.EndDate < CURRENT_DATE THEN
        NEW.Status := 'CheckedOut';
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "hotel chains".auto_checkout() OWNER TO postgres;

--
-- TOC entry 226 (class 1255 OID 17751)
-- Name: auto_checkout_function(); Type: FUNCTION; Schema: hotel chains; Owner: postgres
--

CREATE FUNCTION "hotel chains".auto_checkout_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if the renting period has ended
    IF NEW.EndDate < CURRENT_DATE THEN
        NEW.Status := 'CheckedOut';
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "hotel chains".auto_checkout_function() OWNER TO postgres;

--
-- TOC entry 227 (class 1255 OID 17753)
-- Name: convert_booking_to_renting(); Type: FUNCTION; Schema: hotel chains; Owner: postgres
--

CREATE FUNCTION "hotel chains".convert_booking_to_renting() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Insert into Rentings when the booking starts
    INSERT INTO Rentings (RentingID, RoomID, HotelID, CustomerID, EmployeeID, StartDate, EndDate, Status)
    VALUES (
        NEW.BookingID,  -- Use the BookingID as RentingID
        NEW.RoomID,
        (SELECT HotelID FROM Rooms WHERE RoomID = NEW.RoomID), -- Get HotelID from Rooms
        NEW.CustomerID,
        NULL,  -- EmployeeID will be set manually when the guest is checked in
        NEW.StartDate,
        NEW.EndDate,
        'CheckedIn'  -- Set status as CheckedIn
    );

    RETURN NEW;
END;
$$;


ALTER FUNCTION "hotel chains".convert_booking_to_renting() OWNER TO postgres;

--
-- TOC entry 225 (class 1255 OID 17749)
-- Name: prevent_double_booking(); Type: FUNCTION; Schema: hotel chains; Owner: postgres
--

CREATE FUNCTION "hotel chains".prevent_double_booking() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM Bookings 
        WHERE RoomID = NEW.RoomID 
        AND (NEW.StartDate BETWEEN StartDate AND EndDate 
             OR NEW.EndDate BETWEEN StartDate AND EndDate)
    ) THEN
        RAISE EXCEPTION 'Room is already booked for this period';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "hotel chains".prevent_double_booking() OWNER TO postgres;

--
-- TOC entry 229 (class 1255 OID 17757)
-- Name: prevent_multiple_managers(); Type: FUNCTION; Schema: hotel chains; Owner: postgres
--

CREATE FUNCTION "hotel chains".prevent_multiple_managers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (SELECT COUNT(*) FROM Hotels WHERE ManagerID = NEW.ManagerID) > 1 THEN
        RAISE EXCEPTION 'A manager can only manage one hotel';
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "hotel chains".prevent_multiple_managers() OWNER TO postgres;

--
-- TOC entry 230 (class 1255 OID 17759)
-- Name: set_registration_date(); Type: FUNCTION; Schema: hotel chains; Owner: postgres
--

CREATE FUNCTION "hotel chains".set_registration_date() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.DateOfRegistration := CURRENT_DATE;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "hotel chains".set_registration_date() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 223 (class 1259 OID 17707)
-- Name: bookings; Type: TABLE; Schema: hotel chains; Owner: postgres
--

CREATE TABLE "hotel chains".bookings (
    bookingid integer NOT NULL,
    roomid integer,
    hotelid integer,
    customerid integer,
    startdate date NOT NULL,
    enddate date NOT NULL,
    status character varying(20) DEFAULT 'Booked'::character varying,
    CONSTRAINT bookings_status_check CHECK (((status)::text = ANY ((ARRAY['Booked'::character varying, 'Cancelled'::character varying])::text[])))
);


ALTER TABLE "hotel chains".bookings OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 17695)
-- Name: customers; Type: TABLE; Schema: hotel chains; Owner: postgres
--

CREATE TABLE "hotel chains".customers (
    firstname character varying(20),
    lastname character varying(20),
    customerid integer NOT NULL,
    address character varying(20),
    dateofregistration date
);


ALTER TABLE "hotel chains".customers OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 17667)
-- Name: employees; Type: TABLE; Schema: hotel chains; Owner: postgres
--

CREATE TABLE "hotel chains".employees (
    efirstname character varying(20),
    elastname character varying(20),
    employeeid integer NOT NULL,
    ssnsin integer,
    eaddress character varying(20),
    hotelid integer,
    erole character varying(30)
);


ALTER TABLE "hotel chains".employees OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 17650)
-- Name: hotelchains; Type: TABLE; Schema: hotel chains; Owner: postgres
--

CREATE TABLE "hotel chains".hotelchains (
    chainid integer NOT NULL,
    cname character varying(30),
    num_of_hotels integer,
    caddress character varying(50),
    rating integer,
    cemail character varying(50),
    cphone integer
);


ALTER TABLE "hotel chains".hotelchains OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 17655)
-- Name: hotels; Type: TABLE; Schema: hotel chains; Owner: postgres
--

CREATE TABLE "hotel chains".hotels (
    hotelid integer NOT NULL,
    haddress character varying(50),
    hname character varying(30),
    num_of_rooms integer,
    hemail character varying(50),
    hphone integer,
    chainid integer,
    managerid integer
);


ALTER TABLE "hotel chains".hotels OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 17724)
-- Name: rentings; Type: TABLE; Schema: hotel chains; Owner: postgres
--

CREATE TABLE "hotel chains".rentings (
    rentingid integer NOT NULL,
    roomid integer,
    hotelid integer,
    customerid integer,
    employeeid integer,
    startdate date NOT NULL,
    enddate date NOT NULL,
    status character varying(20) DEFAULT 'CheckedIn'::character varying,
    CONSTRAINT rentings_status_check CHECK (((status)::text = ANY ((ARRAY['CheckedIn'::character varying, 'CheckedOut'::character varying])::text[])))
);


ALTER TABLE "hotel chains".rentings OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 17682)
-- Name: rooms; Type: TABLE; Schema: hotel chains; Owner: postgres
--

CREATE TABLE "hotel chains".rooms (
    roomid integer NOT NULL,
    hotelid integer NOT NULL,
    price numeric,
    view_type character varying(20),
    amenities text[],
    damages text[],
    extendable boolean,
    capacity integer,
    CONSTRAINT chk_price_positive CHECK ((price > (0)::numeric)),
    CONSTRAINT rooms_view_type_check CHECK ((((view_type)::text = 'sea'::text) OR ((view_type)::text = 'mountain'::text)))
);


ALTER TABLE "hotel chains".rooms OWNER TO postgres;

--
-- TOC entry 4966 (class 0 OID 17707)
-- Dependencies: 223
-- Data for Name: bookings; Type: TABLE DATA; Schema: hotel chains; Owner: postgres
--

COPY "hotel chains".bookings (bookingid, roomid, hotelid, customerid, startdate, enddate, status) FROM stdin;
\.


--
-- TOC entry 4965 (class 0 OID 17695)
-- Dependencies: 222
-- Data for Name: customers; Type: TABLE DATA; Schema: hotel chains; Owner: postgres
--

COPY "hotel chains".customers (firstname, lastname, customerid, address, dateofregistration) FROM stdin;
\.


--
-- TOC entry 4963 (class 0 OID 17667)
-- Dependencies: 220
-- Data for Name: employees; Type: TABLE DATA; Schema: hotel chains; Owner: postgres
--

COPY "hotel chains".employees (efirstname, elastname, employeeid, ssnsin, eaddress, hotelid, erole) FROM stdin;
Spongebob	Squarepants	1	1	432 Pinapple St	1	Manager
Squid	Ward	2	2	444 Statue St	2	Manager
Patrick	Starfish	3	3	565 Rock Rd	3	Manager
Sandy	Cheeks	4	4	35 Dome Blvd	4	Manager
Eugene	Crabs	5	5	342 Crabby St	5	Manager
Gary	Snail	6	6	431 Pinapple St	6	Manager
Plankton	Plankton	7	7	342 Chum St	7	Manager
Karen	Computer	8	8	342 Chummy Dr	8	Manager
Hwang	Hyunjin	9	9	324 Rock Star Dr	9	Manager
Lee	Yong-bok	10	10	14 NoEasy St	10	Manager
Yang	Jeong-in	11	11	54 GoLive St	11	Manager
Bahng	Chahn	12	12	34 Mixtape Rd	12	Manager
Lee	Min-ho	13	13	59 TheSound St	13	Manager
Kim	Seung-min	14	14	21 Oddinary St	14	Manager
Seo	Chang-bin	15	15	15 Giant St	15	Manager
Kim	Woojin	16	16	32 InLife Rd	16	Manager
Lanita	Lanita	17	17	43 Lan Rd	17	Manager
Meia	Meia	18	18	13 Meteor St	18	Manager
Luluna	Moon	19	19	75 Apollo St	19	Manager
Mingwei	heh	20	20	33 Test Rd	20	Manager
Elia	Asta	21	21	52 Why St	21	Manager
Sunny	Omori	22	22	21 Faraway St	22	Manager
Basil	Leaf	23	23	15 Faraway St	23	Manager
Ellie	Cat	24	24	32 Floofi Rd	24	Manager
Random	Person	25	25	41 NA Rd	25	Manager
Anonym	Weirdo	26	26	14 Incog St	26	Manager
Hector	Rock	28	28	13 PetRock St	28	Manager
Bel	hei	29	29	33 Fifteen Rd	29	Manager
Wise	Chan	30	30	52 Fifteen St	30	Manager
Aubrey	eggplant	31	31	25 Faraway St	31	Manager
Kel	bro	32	32	41 Faraway St	32	Manager
Hero	bro	33	33	32 Faraway St	33	Manager
Minerva	Athena	34	34	13 Wisdom Rd	34	Manager
Scylla	SeaMonster	35	35	64 Monster St	35	Manager
Lotus	Eater	36	36	134 Island Rd	36	Manager
Polites	Polyphemus	37	37	31 Giant Rd	37	Manager
Ody	Ithaca	38	38	15 Monsters St	38	Manager
Calypso	Mnestia	39	39	32 Paradise St	39	Manager
Ares	Nolan	40	40	31 Wrath St	40	Manager
Circes	Mercury	41	41	13 Island St	41	Manager
\.


--
-- TOC entry 4961 (class 0 OID 17650)
-- Dependencies: 218
-- Data for Name: hotelchains; Type: TABLE DATA; Schema: hotel chains; Owner: postgres
--

COPY "hotel chains".hotelchains (chainid, cname, num_of_hotels, caddress, rating, cemail, cphone) FROM stdin;
1	Crabby Patty Resorts	5	2432 Bikini Bottom	5	squid@crabbypattyresort.com	755882
2	Straight Kids Hotels	5	2017 Seoul Street	3	service@straightkidshotels.ca	201820
3	Samosa Suites	5	324 Ellie Drive	4	reception@samosasuites.ca	32532435
4	Noodles Hotel chain	5	3253 Noodle Avenue	2	reception@noodlechain.ca	42535436
5	Epic Hotels	5	600 Ithaca Street	5	bookings@epichotels.com	600324643
\.


--
-- TOC entry 4962 (class 0 OID 17655)
-- Dependencies: 219
-- Data for Name: hotels; Type: TABLE DATA; Schema: hotel chains; Owner: postgres
--

COPY "hotel chains".hotels (hotelid, haddress, hname, num_of_rooms, hemail, hphone, chainid, managerid) FROM stdin;
1	432 Pinapple St	Sponge Hotel	5	sponge@bobhotels.com	3253254	1	1
2	433 Statue St	Squid Hotel	5	squid@wardhotels.com	23472389	1	2
3	431 Rock Rd	Star Hotel	5	patrick@starhotels.com	2423265	1	3
4	96 Dome Blvd	Squirrel Resort	5	sandy@squirrelresort.com	890854	1	4
5	14 Krusty Rd	Crabby Resort	5	crabs@crabbyresort.com	43285	1	5
6	431 Pinapple St	Snail Suites	5	gary@snailsuites.com	532890	1	6
7	95 Bucket Blvd	Chum Suites	5	plankton@chumsuites.com	532890	1	7
8	89 Bucket Blvd	Puter Hotel	5	Karen@puterhotel.com	2432890	1	8
9	41 Toronto St	Hyun Hotel	5	hyunjin@straighthotels.com	5635565	2	9
10	93 Mexico St	Felix Suites	5	felix@straighthotelss.com	9787245	2	10
11	48 London Rd	I.N. inns	5	in@straighthotels.com	23462165	2	11
12	84 Harvard Blvd	Bang Resort	5	bangchan@straighthotels.com	829532	2	12
13	67 Puppy Rd	Know Resort	5	leeknow@straighthotels.com	73428053	2	13
14	327 Rabbit St	Seung Suites	5	seungmin@straighthotels.com	382490	2	14
15	84 Piggy Blvd	Chang Suites	5	changbin@straighthotels.com	890435	2	15
16	98 Toronto St	Woo Hotel	5	woojin@straighthotels.com	7980325	2	16
17	89 Space Blvd	Lanita Inn	5	lanita@samosachain.com	1235326	3	17
18	34 Apollo St	Meia Suites	5	meia@samosachain.com	5478235	3	18
19	53 Apollo St	Luluna Suites	5	luluna@samosachain.com	8904237	3	19
20	134 Moon Av	Mingwei Hotel	5	mingwei@samosachain.com	4327895	3	20
21	538 Sleepy Av	Elia suites	5	@eliasamosachain.com	4327905	3	21
22	68 White St	Omori Inn	5	omocat@samosachain.com	788032	3	22
23	853 Boot St	Basil Suites	5	basilleaf@samosachain.com	437891	3	23
24	3253 Ellie St	Ellie Hotel	5	ellie@samosachain.com	34890798	3	24
25	985 Sloth Av	Ramen Suites	5	ramen@noodleschain.com	438953	4	25
26	89 Glutton Blvd	Somen Hotel	5	somen@noodleschain.com	4379032	4	26
28	34 Glutton Blvd	Udon Hotel	5	udon@noodleschain.com	989326	4	28
29	13 Pride St	Rice Hotel	5	rice@noodleschain.com	129853	4	29
30	34 Avarice St	Fettucine Suites	5	fettucine@noodleschain.com	1598324	4	30
31	35 Agony Av	Penne Inn	5	penne@noodleschain.com	894321	4	31
32	40 Envy Dr	Macaroni Inn	5	macaroni@noodleschain.com	3742908	4	32
33	23 Wrath St	Pasta Hotel	5	pasta@noodleschain.com	348901	4	33
34	32 Pantheon Lane	Warriors Inn	5	warriors@epichotels.com	489735	5	34
35	34 Carribean St	Scyllas Lair	5	scylla@epichotels.com	135253	5	35
36	32 Carribean St	Lotus Hotel	5	lotus@epichotels.com	48902	5	36
37	98 Pacific Av	Cyclops Suites	5	cyclops@epichotels.com	348902	5	37
38	432 Ithaca St	Monsters Hotel	5	monsters@epichotels.com	803245	5	38
39	53 Salem St	Calypso Suites	5	calypso@epichotels.com	437982	5	39
40	14 Spartan Av	Thunder Suites	5	thunder@epichotels.com	123083	5	40
41	73 Salem St	Nymphs Inn	5	nymphs@epichotels.com	128923	5	41
\.


--
-- TOC entry 4967 (class 0 OID 17724)
-- Dependencies: 224
-- Data for Name: rentings; Type: TABLE DATA; Schema: hotel chains; Owner: postgres
--

COPY "hotel chains".rentings (rentingid, roomid, hotelid, customerid, employeeid, startdate, enddate, status) FROM stdin;
\.


--
-- TOC entry 4964 (class 0 OID 17682)
-- Dependencies: 221
-- Data for Name: rooms; Type: TABLE DATA; Schema: hotel chains; Owner: postgres
--

COPY "hotel chains".rooms (roomid, hotelid, price, view_type, amenities, damages, extendable, capacity) FROM stdin;
1	1	300.00	sea	{WiFi,TV,Kitchenette,Futon,"2 Bathrooms"}	{"Scratched Tables"}	f	5
2	1	100.0	sea	{Wifi,TV,"free coffee"}	{"stained curtains"}	t	1
3	1	150.0	mountain	{Wifi,TV,Minibar}	{"Uneven table"}	t	2
4	1	70.0	mountain	{Wifi,TV}	{"cracked bedboard","broken lamp"}	f	1
5	1	270.0	mountain	{Wifi,TV,Kitchenette,"disability accomodation"}	{}	f	4
6	2	200.00	sea	{WiFi,TV,Futon}	{"broken light"}	f	3
7	2	300.0	mountain	{Wifi,TV,Futon,Minibar,kitchenette}	{"Damaged chairs"}	f	5
8	2	150.0	mountain	{Wifi,TV}	{}	t	2
9	2	70.0	sea	{Wifi,TV}	{"cracked bedboard","broken lamp"}	f	1
10	2	300.0	mountain	{Wifi,TV,Kitchenette,Bathtub}	{"Damaged floorboard","damaged couch cushion"}	t	4
11	3	200.00	mountain	{WiFi,TV,Futon}	{"broken light"}	f	3
12	3	70.0	sea	{Wifi}	{"Finicky showerhead"}	f	1
13	3	200.0	mountain	{Wifi,TV}	{}	t	2
14	3	200.0	sea	{Wifi,TV,bathtub}	{"sticky doorhandle"}	t	2
15	3	220.0	mountain	{Wifi,TV,Kitchenette}	{"flickering lights"}	t	3
16	4	200.00	sea	{WiFi,TV,Futon}	{"broken light"}	f	3
17	4	70.0	sea	{Wifi}	{}	f	1
18	4	200.0	mountain	{Wifi,TV}	{}	t	2
19	4	220.0	mountain	{Wifi,TV,Minibar}	{"sticky doorhandle"}	t	2
20	4	240.0	mountain	{Wifi,TV,Kitchenette}	{}	t	4
21	5	300.00	sea	{WiFi,TV,Futon,kitchenette,bathtub}	{}	f	6
22	5	100.0	mountain	{Wifi,Gym}	{}	t	1
23	5	150.0	mountain	{Wifi,TV,Gym}	{}	t	2
24	5	220.0	sea	{Wifi,TV,Minibar}	{"sticky doorhandle"}	f	3
25	5	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
26	6	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
27	6	100.0	mountain	{Wifi,Gym}	{}	t	1
28	6	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
29	6	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
30	6	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
31	7	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
32	7	100.0	mountain	{Wifi,Gym}	{}	t	1
33	7	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
34	7	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
35	7	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
36	8	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
37	8	100.0	mountain	{Wifi,Gym}	{}	t	1
38	8	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
39	8	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
40	8	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
41	9	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
42	9	100.0	mountain	{Wifi,Gym}	{}	t	1
43	9	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
44	9	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
45	9	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
46	10	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
47	10	100.0	mountain	{Wifi,Gym}	{}	t	1
48	10	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
49	10	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
50	10	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
51	12	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
52	12	100.0	mountain	{Wifi,Gym}	{}	t	1
53	12	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
54	12	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
55	12	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
56	13	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
57	13	100.0	mountain	{Wifi,Gym}	{}	t	1
58	13	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
59	13	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
60	13	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
61	14	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
62	14	100.0	mountain	{Wifi,Gym}	{}	t	1
63	14	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
64	14	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
65	14	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
66	15	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
67	15	100.0	mountain	{Wifi,Gym}	{}	t	1
68	15	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
69	15	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
70	15	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
71	16	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
72	16	100.0	mountain	{Wifi,Gym}	{}	t	1
73	16	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
74	16	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
75	16	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
76	17	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
77	17	100.0	mountain	{Wifi,Gym}	{}	t	1
78	17	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
79	17	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
80	17	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
81	18	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
82	18	100.0	mountain	{Wifi,Gym}	{}	t	1
83	18	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
84	18	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
85	18	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
86	19	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
87	19	100.0	mountain	{Wifi,Gym}	{}	t	1
88	19	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
89	19	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
90	19	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
91	20	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
92	20	100.0	mountain	{Wifi,Gym}	{}	t	1
93	20	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
94	20	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
95	20	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
96	21	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
97	21	100.0	mountain	{Wifi,Gym}	{}	t	1
98	21	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
99	21	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
100	21	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
101	22	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
102	22	100.0	mountain	{Wifi,Gym}	{}	t	1
103	22	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
104	22	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
105	22	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
106	23	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
107	23	100.0	mountain	{Wifi,Gym}	{}	t	1
108	23	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
109	23	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
110	23	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
111	24	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
112	24	100.0	mountain	{Wifi,Gym}	{}	t	1
113	24	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
114	24	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
115	24	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
116	25	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
117	25	100.0	mountain	{Wifi,Gym}	{}	t	1
118	25	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
119	25	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
120	25	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
121	26	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
122	26	100.0	mountain	{Wifi,Gym}	{}	t	1
123	26	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
124	26	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
125	26	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
131	28	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
132	28	100.0	mountain	{Wifi,Gym}	{}	t	1
133	28	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
134	28	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
135	28	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
136	29	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
137	29	100.0	mountain	{Wifi,Gym}	{}	t	1
138	29	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
139	29	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
140	29	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
141	30	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
142	30	100.0	mountain	{Wifi,Gym}	{}	t	1
143	30	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
144	30	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
145	30	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
146	31	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
147	31	100.0	mountain	{Wifi,Gym}	{}	t	1
148	31	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
149	31	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
150	31	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
151	32	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
152	32	100.0	mountain	{Wifi,Gym}	{}	t	1
153	32	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
154	32	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
155	32	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
156	33	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
157	33	100.0	mountain	{Wifi,Gym}	{}	t	1
158	33	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
159	33	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
160	33	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
161	34	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
162	34	100.0	mountain	{Wifi,Gym}	{}	t	1
163	34	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
164	34	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
165	34	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
166	35	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
167	35	100.0	mountain	{Wifi,Gym}	{}	t	1
168	35	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
169	35	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
170	35	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
171	36	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
172	36	100.0	mountain	{Wifi,Gym}	{}	t	1
173	36	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
174	36	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
175	36	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
176	37	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
177	37	100.0	mountain	{Wifi,Gym}	{}	t	1
178	37	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
179	37	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
180	37	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
181	38	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
182	38	100.0	mountain	{Wifi,Gym}	{}	t	1
183	38	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
184	38	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
185	38	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
186	39	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
187	39	100.0	mountain	{Wifi,Gym}	{}	t	1
188	39	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
189	39	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
190	39	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
191	40	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
192	40	100.0	mountain	{Wifi,Gym}	{}	t	1
193	40	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
194	40	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
195	40	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
196	41	370.00	sea	{WiFi,TV,Futon,kitchenette,bathtub,Gym}	{}	f	6
197	41	100.0	mountain	{Wifi,Gym}	{}	t	1
198	41	150.0	mountain	{Wifi,TV,Gym}	{"broken clothing hangers"}	t	2
199	41	220.0	sea	{Wifi,TV,Minibar}	{"broken lamp"}	f	3
200	41	240.0	sea	{Wifi,TV,Kitchenette}	{}	t	4
\.


--
-- TOC entry 4795 (class 2606 OID 17713)
-- Name: bookings bookings_pkey; Type: CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".bookings
    ADD CONSTRAINT bookings_pkey PRIMARY KEY (bookingid);


--
-- TOC entry 4792 (class 2606 OID 17699)
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (customerid);


--
-- TOC entry 4786 (class 2606 OID 17671)
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (employeeid);


--
-- TOC entry 4780 (class 2606 OID 17654)
-- Name: hotelchains hotelchains_pkey; Type: CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".hotelchains
    ADD CONSTRAINT hotelchains_pkey PRIMARY KEY (chainid);


--
-- TOC entry 4782 (class 2606 OID 17661)
-- Name: hotels hotels_managerid_key; Type: CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".hotels
    ADD CONSTRAINT hotels_managerid_key UNIQUE (managerid);


--
-- TOC entry 4784 (class 2606 OID 17659)
-- Name: hotels hotels_pkey; Type: CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".hotels
    ADD CONSTRAINT hotels_pkey PRIMARY KEY (hotelid);


--
-- TOC entry 4800 (class 2606 OID 17730)
-- Name: rentings rentings_pkey; Type: CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".rentings
    ADD CONSTRAINT rentings_pkey PRIMARY KEY (rentingid);


--
-- TOC entry 4790 (class 2606 OID 17689)
-- Name: rooms rooms_pkey; Type: CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (roomid, hotelid);


--
-- TOC entry 4788 (class 1259 OID 17766)
-- Name: idx_available_rooms; Type: INDEX; Schema: hotel chains; Owner: postgres
--

CREATE INDEX idx_available_rooms ON "hotel chains".rooms USING btree (hotelid, roomid);


--
-- TOC entry 4796 (class 1259 OID 17765)
-- Name: idx_booking_dates; Type: INDEX; Schema: hotel chains; Owner: postgres
--

CREATE INDEX idx_booking_dates ON "hotel chains".bookings USING btree (startdate, enddate);


--
-- TOC entry 4793 (class 1259 OID 17764)
-- Name: idx_customer_address; Type: INDEX; Schema: hotel chains; Owner: postgres
--

CREATE INDEX idx_customer_address ON "hotel chains".customers USING btree (address);


--
-- TOC entry 4797 (class 1259 OID 17767)
-- Name: idx_customer_bookings; Type: INDEX; Schema: hotel chains; Owner: postgres
--

CREATE INDEX idx_customer_bookings ON "hotel chains".bookings USING btree (customerid, startdate);


--
-- TOC entry 4787 (class 1259 OID 17768)
-- Name: idx_employee_hotel; Type: INDEX; Schema: hotel chains; Owner: postgres
--

CREATE INDEX idx_employee_hotel ON "hotel chains".employees USING btree (hotelid);


--
-- TOC entry 4798 (class 1259 OID 17763)
-- Name: idx_roomid; Type: INDEX; Schema: hotel chains; Owner: postgres
--

CREATE INDEX idx_roomid ON "hotel chains".bookings USING btree (roomid);


--
-- TOC entry 4814 (class 2620 OID 17752)
-- Name: rentings auto_checkout; Type: TRIGGER; Schema: hotel chains; Owner: postgres
--

CREATE TRIGGER auto_checkout BEFORE UPDATE ON "hotel chains".rentings FOR EACH ROW EXECUTE FUNCTION "hotel chains".auto_checkout_function();


--
-- TOC entry 4812 (class 2620 OID 17750)
-- Name: bookings prevent_double_booking_trigger; Type: TRIGGER; Schema: hotel chains; Owner: postgres
--

CREATE TRIGGER prevent_double_booking_trigger BEFORE INSERT ON "hotel chains".bookings FOR EACH ROW EXECUTE FUNCTION "hotel chains".prevent_double_booking();


--
-- TOC entry 4815 (class 2620 OID 17756)
-- Name: rentings trigger_auto_checkout; Type: TRIGGER; Schema: hotel chains; Owner: postgres
--

CREATE TRIGGER trigger_auto_checkout BEFORE UPDATE ON "hotel chains".rentings FOR EACH ROW EXECUTE FUNCTION "hotel chains".auto_checkout();


--
-- TOC entry 4813 (class 2620 OID 17754)
-- Name: bookings trigger_convert_booking; Type: TRIGGER; Schema: hotel chains; Owner: postgres
--

CREATE TRIGGER trigger_convert_booking AFTER UPDATE ON "hotel chains".bookings FOR EACH ROW WHEN (((new.startdate = CURRENT_DATE) AND ((new.status)::text = 'Booked'::text))) EXECUTE FUNCTION "hotel chains".convert_booking_to_renting();


--
-- TOC entry 4810 (class 2620 OID 17758)
-- Name: hotels trigger_prevent_multiple_managers; Type: TRIGGER; Schema: hotel chains; Owner: postgres
--

CREATE TRIGGER trigger_prevent_multiple_managers BEFORE UPDATE ON "hotel chains".hotels FOR EACH ROW EXECUTE FUNCTION "hotel chains".prevent_multiple_managers();


--
-- TOC entry 4811 (class 2620 OID 17760)
-- Name: customers trigger_set_registration_date; Type: TRIGGER; Schema: hotel chains; Owner: postgres
--

CREATE TRIGGER trigger_set_registration_date BEFORE INSERT ON "hotel chains".customers FOR EACH ROW EXECUTE FUNCTION "hotel chains".set_registration_date();


--
-- TOC entry 4805 (class 2606 OID 17719)
-- Name: bookings bookings_customerid_fkey; Type: FK CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".bookings
    ADD CONSTRAINT bookings_customerid_fkey FOREIGN KEY (customerid) REFERENCES "hotel chains".customers(customerid) ON DELETE SET NULL;


--
-- TOC entry 4806 (class 2606 OID 17714)
-- Name: bookings bookings_roomid_hotelid_fkey; Type: FK CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".bookings
    ADD CONSTRAINT bookings_roomid_hotelid_fkey FOREIGN KEY (roomid, hotelid) REFERENCES "hotel chains".rooms(roomid, hotelid) ON DELETE CASCADE;


--
-- TOC entry 4803 (class 2606 OID 17672)
-- Name: employees employees_hotelid_fkey; Type: FK CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".employees
    ADD CONSTRAINT employees_hotelid_fkey FOREIGN KEY (hotelid) REFERENCES "hotel chains".hotels(hotelid);


--
-- TOC entry 4801 (class 2606 OID 17677)
-- Name: hotels fk_manager_id; Type: FK CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".hotels
    ADD CONSTRAINT fk_manager_id FOREIGN KEY (managerid) REFERENCES "hotel chains".employees(employeeid);


--
-- TOC entry 4802 (class 2606 OID 17662)
-- Name: hotels hotels_chainid_fkey; Type: FK CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".hotels
    ADD CONSTRAINT hotels_chainid_fkey FOREIGN KEY (chainid) REFERENCES "hotel chains".hotelchains(chainid);


--
-- TOC entry 4807 (class 2606 OID 17736)
-- Name: rentings rentings_customerid_fkey; Type: FK CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".rentings
    ADD CONSTRAINT rentings_customerid_fkey FOREIGN KEY (customerid) REFERENCES "hotel chains".customers(customerid) ON DELETE CASCADE;


--
-- TOC entry 4808 (class 2606 OID 17741)
-- Name: rentings rentings_employeeid_fkey; Type: FK CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".rentings
    ADD CONSTRAINT rentings_employeeid_fkey FOREIGN KEY (employeeid) REFERENCES "hotel chains".employees(employeeid) ON DELETE SET NULL;


--
-- TOC entry 4809 (class 2606 OID 17731)
-- Name: rentings rentings_roomid_hotelid_fkey; Type: FK CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".rentings
    ADD CONSTRAINT rentings_roomid_hotelid_fkey FOREIGN KEY (roomid, hotelid) REFERENCES "hotel chains".rooms(roomid, hotelid) ON DELETE CASCADE;


--
-- TOC entry 4804 (class 2606 OID 17690)
-- Name: rooms rooms_hotelid_fkey; Type: FK CONSTRAINT; Schema: hotel chains; Owner: postgres
--

ALTER TABLE ONLY "hotel chains".rooms
    ADD CONSTRAINT rooms_hotelid_fkey FOREIGN KEY (hotelid) REFERENCES "hotel chains".hotels(hotelid) ON DELETE CASCADE;


--
-- TOC entry 2074 (class 826 OID 17747)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO lanita;


-- Completed on 2025-03-31 18:41:48

--
-- PostgreSQL database dump complete
--


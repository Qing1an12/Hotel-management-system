from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError
from pydantic import BaseModel, validator, Field
from datetime import date, datetime
from typing import List, Optional
import os
from dotenv import load_dotenv
import logging

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

load_dotenv()

app = FastAPI(title="Hotel Chains API")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Root endpoint to serve index.html
@app.get("/")
def read_root():
    return FileResponse("static/index.html")

# Database connection
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise ValueError("DATABASE_URL environment variable is not set")

try:
    engine = create_engine(DATABASE_URL)
    with engine.connect() as conn:
        # Test the connection
        conn.execute(text("SELECT 1"))
        logger.info("Database connection test successful")
        
        # Set the search path to include our schema
        conn.execute(text('SET search_path TO "hotel chains", public'))
        logger.info("Search path set successfully")
        
        # Check available schemas
        result = conn.execute(text("SELECT schema_name FROM information_schema.schemata"))
        schemas = [row[0] for row in result]
        logger.info(f"Available schemas: {schemas}")
        
        # Check tables in our schema
        result = conn.execute(text("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'hotel chains'
        """))
        tables = [row[0] for row in result]
        logger.info(f"Tables in 'hotel chains' schema: {tables}")
except SQLAlchemyError as e:
    logger.error(f"Database connection error: {str(e)}")
    raise

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        # Set search path for this session
        db.execute(text('SET search_path TO "hotel chains", public'))
        yield db
    except SQLAlchemyError as e:
        logger.error(f"Database session error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        db.close()

# Models
class RoomSearch(BaseModel):
    start_date: str
    end_date: str
    capacity: Optional[int] = None
    area: Optional[str] = None
    hotel_chain: Optional[str] = None
    max_price: Optional[float] = None

    @validator('start_date', 'end_date')
    def validate_dates(cls, v):
        try:
            date_obj = datetime.strptime(v, '%Y-%m-%d').date()
            if date_obj < date.today():
                raise ValueError("Date cannot be in the past")
            return v
        except ValueError as e:
            raise ValueError(f"Invalid date format. Please use YYYY-MM-DD. Error: {str(e)}")

    @validator('end_date')
    def validate_end_date(cls, v, values):
        if 'start_date' in values:
            start = datetime.strptime(values['start_date'], '%Y-%m-%d').date()
            end = datetime.strptime(v, '%Y-%m-%d').date()
            if end <= start:
                raise ValueError("End date must be after start date")
        return v

class CustomerCreate(BaseModel):
    firstname: str
    lastname: str
    address: str
    customerid: Optional[int] = None

class BookingCreate(BaseModel):
    room_id: int
    customer_id: int
    start_date: str = Field(..., description="Date in YYYY-MM-DD format")
    end_date: str = Field(..., description="Date in YYYY-MM-DD format")

    @validator('start_date', 'end_date')
    def validate_date(cls, v):
        try:
            datetime.strptime(v, '%Y-%m-%d')
            return v
        except ValueError:
            raise ValueError('Date must be in YYYY-MM-DD format')

    @validator('end_date')
    def validate_end_date(cls, v, values):
        if 'start_date' in values:
            start = datetime.strptime(values['start_date'], '%Y-%m-%d')
            end = datetime.strptime(v, '%Y-%m-%d')
            if end <= start:
                raise ValueError('End date must be after start date')
        return v

class RentingCreate(BaseModel):
    booking_id: Optional[int] = None
    room_id: int
    customer_id: int
    employee_id: int
    start_date: str = Field(..., description="Date in YYYY-MM-DD format")
    end_date: str = Field(..., description="Date in YYYY-MM-DD format")

    @validator('start_date', 'end_date')
    def validate_date(cls, v):
        try:
            datetime.strptime(v, '%Y-%m-%d')
            return v
        except ValueError:
            raise ValueError('Date must be in YYYY-MM-DD format')

    @validator('end_date')
    def validate_end_date(cls, v, values):
        if 'start_date' in values:
            start = datetime.strptime(values['start_date'], '%Y-%m-%d')
            end = datetime.strptime(v, '%Y-%m-%d')
            if end <= start:
                raise ValueError('End date must be after start date')
        return v

@app.get("/api/hotel-chains")
def get_hotel_chains(db = Depends(get_db)):
    try:
        result = db.execute(text('SELECT * FROM "hotel chains".hotelchains'))
        rows = []
        for row in result:
            row_dict = {
                "chainid": row.chainid,
                "name": row.cname,
                "num_of_hotels": row.num_of_hotels,
                "address": row.caddress,
                "rating": row.rating,
                "email": row.cemail,
                "phone": row.cphone
            }
            rows.append(row_dict)
        return rows
    except Exception as e:
        logger.error(f"Error in get_hotel_chains: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/hotels")
def get_hotels(chain_id: Optional[int] = None, db = Depends(get_db)):
    try:
        query = 'SELECT * FROM "hotel chains".hotels WHERE 1=1'
        params = {}
        if chain_id:
            query += " AND chainid = :chain_id"
            params['chain_id'] = chain_id
        result = db.execute(text(query), params)
        rows = []
        for row in result:
            row_dict = {
                "hotelid": row.hotelid,
                "address": row.haddress,
                "name": row.hname,
                "num_of_rooms": row.num_of_rooms,
                "email": row.hemail,
                "phone": row.hphone,
                "chainid": row.chainid,
                "managerid": row.managerid
            }
            rows.append(row_dict)
        return rows
    except Exception as e:
        logger.error(f"Error in get_hotels: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/available-rooms")
def get_available_rooms(
    start_date: str,
    end_date: str,
    capacity: Optional[int] = None,
    area: Optional[str] = None,
    hotel_chain: Optional[str] = None,
    max_price: Optional[float] = None,
    db = Depends(get_db)
):
    try:
        # Convert string dates to datetime
        start = datetime.strptime(start_date, '%Y-%m-%d').date()
        end = datetime.strptime(end_date, '%Y-%m-%d').date()
        
        # Base query
        query = """
        SELECT r.*, 
            h.haddress as hotel_address, 
            h.hemail as hotel_email, 
            h.hphone as hotel_phone,
            h.hname as hotel_name,
            hc.cname as chain_name,
            hc.caddress as chain_address,
            hc.cemail as chain_email,
            hc.cphone as chain_phone,
            hc.rating as chain_rating
        FROM "hotel chains".rooms r
        JOIN "hotel chains".hotels h ON r.hotelid = h.hotelid
        JOIN "hotel chains".hotelchains hc ON h.chainid = hc.chainid
        WHERE r.roomid NOT IN (
            SELECT roomid FROM "hotel chains".bookings 
            WHERE status = 'Booked' 
            AND startdate <= :end_date 
            AND enddate >= :start_date
            UNION
            SELECT roomid FROM "hotel chains".rentings 
            WHERE startdate <= :end_date 
            AND enddate >= :start_date
        )
        """
        
        params = {
            "start_date": start,
            "end_date": end
        }
        
        # Add filters
        if capacity:
            query += " AND r.capacity >= :capacity"
            params["capacity"] = capacity
            
        if area:
            query += " AND h.haddress ILIKE :area"
            params["area"] = f"%{area}%"
            
        if hotel_chain:
            query += " AND hc.cname ILIKE :chain"
            params["chain"] = f"%{hotel_chain}%"
            
        if max_price:
            query += " AND r.price <= :max_price"
            params["max_price"] = max_price
            
        # Execute query
        result = db.execute(text(query), params)
        rooms = []
        for row in result:
            room_dict = {
                "roomid": row.roomid,
                "hotelid": row.hotelid,
                "price": float(row.price) if row.price else None,
                "capacity": row.capacity,
                "view": row.view_type,
                "extendable": row.extendable,
                "amenities": row.amenities,
                "damages": row.damages,
                "hotel_name": row.hotel_name,
                "hotel_address": row.hotel_address,
                "hotel_email": row.hotel_email,
                "hotel_phone": row.hotel_phone,
                "chain_name": row.chain_name,
                "chain_address": row.chain_address,
                "chain_email": row.chain_email,
                "chain_phone": row.chain_phone,
                "chain_rating": row.chain_rating
            }
            rooms.append(room_dict)
            
        return rooms
    except Exception as e:
        logger.error(f"Error in get_available_rooms: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to search rooms: {str(e)}")

@app.post("/api/bookings")
def create_booking(booking: BookingCreate, db = Depends(get_db)):
    try:
        # Check if customer exists
        customer_query = """
        SELECT customerid FROM "hotel chains".customers 
        WHERE customerid = :customer_id
        """
        result = db.execute(text(customer_query), {"customer_id": booking.customer_id})
        if not result.first():
            raise HTTPException(status_code=404, detail=f"Customer {booking.customer_id} not found")

        # Check if room exists and get hotel_id
        hotel_query = """
        SELECT hotelid FROM "hotel chains".rooms 
        WHERE roomid = :room_id
        """
        result = db.execute(text(hotel_query), {"room_id": booking.room_id})
        hotel_id = result.scalar()
        if not hotel_id:
            raise HTTPException(status_code=404, detail=f"Room {booking.room_id} not found")
        
        # Check if room is available
        availability_query = """
        SELECT COUNT(*) FROM "hotel chains".bookings 
        WHERE roomid = :room_id 
        AND status = 'Booked'
        AND ((startdate <= :end_date AND enddate >= :start_date)
             OR (startdate >= :start_date AND startdate <= :end_date))
        """
        result = db.execute(text(availability_query), {
            "room_id": booking.room_id,
            "start_date": booking.start_date,
            "end_date": booking.end_date
        })
        if result.scalar() > 0:
            raise HTTPException(status_code=400, detail="Room is not available for the selected dates")
        
        # Generate new booking ID
        booking_id_query = """
        SELECT COALESCE(MAX(bookingid), 0) + 1 FROM "hotel chains".bookings
        """
        result = db.execute(text(booking_id_query))
        booking_id = result.scalar()
        
        # Create booking
        query = """
        INSERT INTO "hotel chains".bookings (bookingid, roomid, hotelid, customerid, startdate, enddate, status)
        VALUES (:booking_id, :room_id, :hotel_id, :customer_id, :start_date, :end_date, 'Booked')
        RETURNING bookingid
        """
        params = {
            "booking_id": booking_id,
            "room_id": booking.room_id,
            "hotel_id": hotel_id,
            "customer_id": booking.customer_id,
            "start_date": booking.start_date,
            "end_date": booking.end_date
        }
        result = db.execute(text(query), params)
        new_booking_id = result.scalar()
        if not new_booking_id:
            raise HTTPException(status_code=500, detail="Failed to create booking")
        
        db.commit()
        return {"bookingid": new_booking_id}
    except HTTPException as e:
        db.rollback()
        raise e
    except Exception as e:
        db.rollback()
        logger.error(f"Error in create_booking: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to create booking: {str(e)}")

@app.post("/api/rentings")
def create_renting(renting: RentingCreate, db = Depends(get_db)):
    try:
        # Check if room exists and get its hotelid
        room_query = 'SELECT hotelid FROM "hotel chains".rooms WHERE roomid = :room_id'
        result = db.execute(text(room_query), {"room_id": renting.room_id})
        room = result.first()
        if not room:
            raise HTTPException(status_code=404, detail="Room not found")
        
        # Check if employee exists
        emp_query = 'SELECT employeeid FROM "hotel chains".employees WHERE employeeid = :employee_id'
        result = db.execute(text(emp_query), {"employee_id": renting.employee_id})
        if not result.first():
            raise HTTPException(status_code=404, detail="Employee not found")
        
        # Check if room is available for the given dates
        availability_query = """
        SELECT COUNT(*) FROM "hotel chains".rentings 
        WHERE roomid = :room_id 
        AND ((startdate <= :end_date AND enddate >= :start_date)
        OR (startdate >= :start_date AND startdate <= :end_date))
        """
        result = db.execute(text(availability_query), {
            "room_id": renting.room_id,
            "start_date": datetime.strptime(renting.start_date, '%Y-%m-%d').date(),
            "end_date": datetime.strptime(renting.end_date, '%Y-%m-%d').date()
        })
        if result.scalar() > 0:
            raise HTTPException(status_code=400, detail="Room is not available for the selected dates")
        
        # Create the renting
        query = """
        INSERT INTO "hotel chains".rentings (roomid, hotelid, customerid, employeeid, startdate, enddate, status)
        VALUES (:room_id, :hotel_id, :customer_id, :employee_id, :start_date, :end_date, 'CheckedIn')
        RETURNING rentingid
        """
        params = {
            **renting.dict(),
            "hotel_id": room[0],
            "start_date": datetime.strptime(renting.start_date, '%Y-%m-%d').date(),
            "end_date": datetime.strptime(renting.end_date, '%Y-%m-%d').date()
        }
        result = db.execute(text(query), params)
        db.commit()
        
        # If this was from a booking, update the booking status
        if renting.booking_id:
            update_query = """
            UPDATE "hotel chains".bookings 
            SET status = 'CheckedIn'
            WHERE bookingid = :booking_id
            """
            db.execute(text(update_query), {"booking_id": renting.booking_id})
            db.commit()
            
        return {"rentingid": result.scalar()}
    except HTTPException as e:
        db.rollback()
        raise e
    except Exception as e:
        db.rollback()
        logger.error(f"Error in create_renting: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to create renting: {str(e)}")

@app.get("/api/employees")
def get_employees(hotel_id: Optional[int] = None, db = Depends(get_db)):
    try:
        query = 'SELECT * FROM "hotel chains".employees WHERE 1=1'
        params = {}
        if hotel_id:
            query += " AND hotelid = :hotel_id"
            params["hotel_id"] = hotel_id
        
        result = db.execute(text(query), params)
        rows = []
        for row in result:
            row_dict = {
                "employeeid": row.employeeid,
                "firstname": row.efirstname,
                "lastname": row.elastname,
                "ssnsin": row.ssnsin,
                "address": row.eaddress,
                "hotelid": row.hotelid,
                "role": row.erole,
                "phone": row.ephone,
                "email": row.eemail
            }
            rows.append(row_dict)
        return rows
    except Exception as e:
        logger.error(f"Error in get_employees: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/customers/{customer_id}/bookings")
def get_customer_bookings(customer_id: int, db = Depends(get_db)):
    try:
        query = """
        SELECT b.bookingid, b.roomid, b.hotelid, b.customerid, 
               b.startdate, b.enddate, b.status,
               r.price, r.view_type, r.capacity,
               h.hname as hotel_name, h.haddress as hotel_address,
               c.cfirstname as customer_firstname, c.clastname as customer_lastname
        FROM "hotel chains".bookings b
        JOIN "hotel chains".rooms r ON b.roomid = r.roomid
        JOIN "hotel chains".hotels h ON b.hotelid = h.hotelid
        JOIN "hotel chains".customers c ON b.customerid = c.customerid
        WHERE b.customerid = :customer_id
        ORDER BY b.startdate DESC
        """
        result = db.execute(text(query), {"customer_id": customer_id})
        rows = []
        for row in result:
            row_dict = {
                "bookingid": row.bookingid,
                "roomid": row.roomid,
                "hotelid": row.hotelid,
                "customerid": row.customerid,
                "startdate": row.startdate,
                "enddate": row.enddate,
                "status": row.status,
                "price": float(row.price) if row.price else None,
                "view_type": row.view_type,
                "capacity": row.capacity,
                "hotel_name": row.hotel_name,
                "hotel_address": row.hotel_address,
                "customer_name": f"{row.customer_firstname} {row.customer_lastname}"
            }
            rows.append(row_dict)
        return rows
    except Exception as e:
        logger.error(f"Error in get_customer_bookings: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/customers/{customer_id}/rentings")
def get_customer_rentings(customer_id: int, db = Depends(get_db)):
    try:
        query = """
        SELECT r.rentingid, r.roomid, r.hotelid, r.customerid, 
               r.employeeid, r.startdate, r.enddate, r.status,
               rm.price, rm.view_type, rm.capacity,
               h.hname as hotel_name, h.haddress as hotel_address,
               e.efirstname as employee_firstname, e.elastname as employee_lastname,
               c.cfirstname as customer_firstname, c.clastname as customer_lastname
        FROM "hotel chains".rentings r
        JOIN "hotel chains".rooms rm ON r.roomid = rm.roomid
        JOIN "hotel chains".hotels h ON r.hotelid = h.hotelid
        JOIN "hotel chains".customers c ON r.customerid = c.customerid
        LEFT JOIN "hotel chains".employees e ON r.employeeid = e.employeeid
        WHERE r.customerid = :customer_id
        ORDER BY r.startdate DESC
        """
        result = db.execute(text(query), {"customer_id": customer_id})
        rows = []
        for row in result:
            row_dict = {
                "rentingid": row.rentingid,
                "roomid": row.roomid,
                "hotelid": row.hotelid,
                "customerid": row.customerid,
                "employeeid": row.employeeid,
                "startdate": row.startdate,
                "enddate": row.enddate,
                "status": row.status,
                "price": float(row.price) if row.price else None,
                "view_type": row.view_type,
                "capacity": row.capacity,
                "hotel_name": row.hotel_name,
                "hotel_address": row.hotel_address,
                "employee_name": f"{row.employee_firstname} {row.employee_lastname}" if row.employee_firstname else None,
                "customer_name": f"{row.customer_firstname} {row.customer_lastname}"
            }
            rows.append(row_dict)
        return rows
    except Exception as e:
        logger.error(f"Error in get_customer_rentings: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/customers")
def create_customer(customer: CustomerCreate, db = Depends(get_db)):
    try:
        # If customerid is provided, check if it exists
        if customer.customerid:
            check_query = """
            SELECT customerid FROM "hotel chains".customers 
            WHERE customerid = :customerid
            """
            result = db.execute(text(check_query), {"customerid": customer.customerid})
            if result.first():
                raise HTTPException(status_code=400, detail=f"Customer with ID {customer.customerid} already exists")
        
        # If no customerid provided, get the next available ID
        if not customer.customerid:
            id_query = """
            SELECT COALESCE(MAX(customerid), 0) + 1 
            FROM "hotel chains".customers
            """
            result = db.execute(text(id_query))
            customer.customerid = result.scalar()
        
        # Insert the customer
        query = """
        INSERT INTO "hotel chains".customers (customerid, firstname, lastname, address, dateofregistration)
        VALUES (:customerid, :firstname, :lastname, :address, CURRENT_DATE)
        RETURNING customerid
        """
        result = db.execute(text(query), customer.dict())
        customer_id = result.scalar()
        db.commit()
        return {"customerid": customer_id}
    except Exception as e:
        db.rollback()
        logger.error(f"Error in create_customer: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to create customer: {str(e)}")

@app.put("/api/customers/{customer_id}")
def update_customer(customer_id: int, customer: CustomerCreate, db = Depends(get_db)):
    try:
        # Check if customer exists
        check_query = """
        SELECT customerid FROM "hotel chains".customers 
        WHERE customerid = :customer_id
        """
        result = db.execute(text(check_query), {"customer_id": customer_id})
        if not result.first():
            raise HTTPException(status_code=404, detail=f"Customer {customer_id} not found")
        
        # Check for active bookings or rentings
        check_active_query = """
        SELECT 
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM "hotel chains".bookings 
                    WHERE customerid = :customer_id 
                    AND status IN ('Booked', 'CheckedIn')
                ) THEN true
                WHEN EXISTS (
                    SELECT 1 FROM "hotel chains".rentings 
                    WHERE customerid = :customer_id 
                    AND status = 'CheckedIn'
                ) THEN true
                ELSE false
            END as has_active
        """
        result = db.execute(text(check_active_query), {"customer_id": customer_id})
        if result.scalar():
            raise HTTPException(
                status_code=400, 
                detail="Cannot update customer with active bookings or rentings"
            )
        
        # Update customer
        query = """
        UPDATE "hotel chains".customers 
        SET firstname = :firstname, lastname = :lastname, address = :address
        WHERE customerid = :customer_id
        """
        params = {**customer.dict(), "customer_id": customer_id}
        result = db.execute(text(query), params)
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Customer {customer_id} not found")
        db.commit()
        return {"message": "Customer updated successfully"}
    except HTTPException as e:
        db.rollback()
        raise e
    except Exception as e:
        db.rollback()
        logger.error(f"Error in update_customer: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/customers/{customer_id}")
def delete_customer(customer_id: int, db = Depends(get_db)):
    try:
        # Check if customer exists
        check_query = """
        SELECT customerid FROM "hotel chains".customers 
        WHERE customerid = :customer_id
        """
        result = db.execute(text(check_query), {"customer_id": customer_id})
        if not result.first():
            raise HTTPException(status_code=404, detail=f"Customer {customer_id} not found")
        
        # Check for active bookings or rentings
        check_active_query = """
        SELECT 
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM "hotel chains".bookings 
                    WHERE customerid = :customer_id 
                    AND status IN ('Booked', 'CheckedIn')
                ) THEN true
                WHEN EXISTS (
                    SELECT 1 FROM "hotel chains".rentings 
                    WHERE customerid = :customer_id 
                    AND status = 'CheckedIn'
                ) THEN true
                ELSE false
            END as has_active
        """
        result = db.execute(text(check_active_query), {"customer_id": customer_id})
        if result.scalar():
            raise HTTPException(
                status_code=400, 
                detail="Cannot delete customer with active bookings or rentings"
            )
        
        # Delete customer
        query = 'DELETE FROM "hotel chains".customers WHERE customerid = :customer_id'
        result = db.execute(text(query), {"customer_id": customer_id})
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Customer {customer_id} not found")
        db.commit()
        return {"message": "Customer deleted successfully"}
    except HTTPException as e:
        db.rollback()
        raise e
    except Exception as e:
        db.rollback()
        logger.error(f"Error in delete_customer: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/views/room-capacity")
def get_room_capacity_view(db = Depends(get_db)):
    try:
        query = """
        SELECT h.name as hotel_name, COUNT(*) as total_rooms,
               SUM(CASE WHEN r.capacity = 1 THEN 1 ELSE 0 END) as single_rooms,
               SUM(CASE WHEN r.capacity = 2 THEN 1 ELSE 0 END) as double_rooms,
               SUM(CASE WHEN r.capacity = 3 THEN 1 ELSE 0 END) as triple_rooms,
               SUM(CASE WHEN r.capacity >= 4 THEN 1 ELSE 0 END) as other_rooms
        FROM "hotel chains".hotels h
        JOIN "hotel chains".rooms r ON h.hotelid = r.hotelid
        GROUP BY h.hotelid, h.name
        ORDER BY h.name
        """
        result = db.execute(text(query))
        rows = []
        for row in result:
            row_dict = {}
            for idx, col in enumerate(result.keys()):
                row_dict[col] = row[idx]
            rows.append(row_dict)
        return rows
    except Exception as e:
        logger.error(f"Error in get_room_capacity_view: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/views/room-area")
def get_room_area_view(db = Depends(get_db)):
    try:
        query = """
        SELECT h.name as hotel_name, r.area, COUNT(*) as room_count,
               MIN(r.price) as min_price, MAX(r.price) as max_price,
               AVG(r.price) as avg_price
        FROM "hotel chains".hotels h
        JOIN "hotel chains".rooms r ON h.hotelid = r.hotelid
        GROUP BY h.hotelid, h.name, r.area
        ORDER BY h.name, r.area
        """
        result = db.execute(text(query))
        rows = []
        for row in result:
            row_dict = {}
            for idx, col in enumerate(result.keys()):
                row_dict[col] = row[idx]
            rows.append(row_dict)
        return rows
    except Exception as e:
        logger.error(f"Error in get_room_area_view: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/hotels/{hotel_id}")
def update_hotel(hotel_id: int, hotel_data: dict, db = Depends(get_db)):
    try:
        # Check if hotel exists
        check_query = """
        SELECT hotelid FROM "hotel chains".hotels 
        WHERE hotelid = :hotel_id
        """
        result = db.execute(text(check_query), {"hotel_id": hotel_id})
        if not result.first():
            raise HTTPException(status_code=404, detail=f"Hotel {hotel_id} not found")
        
        # Check if chain exists
        if "chain_id" in hotel_data:
            chain_query = """
            SELECT chainid FROM "hotel chains".hotelchains 
            WHERE chainid = :chain_id
            """
            result = db.execute(text(chain_query), {"chain_id": hotel_data["chain_id"]})
            if not result.first():
                raise HTTPException(status_code=404, detail=f"Hotel chain {hotel_data['chain_id']} not found")
        
        # Check if manager exists
        if "manager_id" in hotel_data:
            manager_query = """
            SELECT employeeid FROM "hotel chains".employees 
            WHERE employeeid = :manager_id
            """
            result = db.execute(text(manager_query), {"manager_id": hotel_data["manager_id"]})
            if not result.first():
                raise HTTPException(status_code=404, detail=f"Employee {hotel_data['manager_id']} not found")
        
        # Check for active bookings or rentings if trying to change chain
        if "chain_id" in hotel_data:
            check_active_query = """
            SELECT 
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM "hotel chains".bookings b
                        JOIN "hotel chains".rooms r ON b.roomid = r.roomid
                        WHERE r.hotelid = :hotel_id 
                        AND b.status IN ('Booked', 'CheckedIn')
                    ) THEN true
                    WHEN EXISTS (
                        SELECT 1 FROM "hotel chains".rentings rt
                        JOIN "hotel chains".rooms r ON rt.roomid = r.roomid
                        WHERE r.hotelid = :hotel_id 
                        AND rt.status = 'CheckedIn'
                    ) THEN true
                    ELSE false
                END as has_active
            """
            result = db.execute(text(check_active_query), {"hotel_id": hotel_id})
            if result.scalar():
                raise HTTPException(
                    status_code=400, 
                    detail="Cannot change hotel chain while there are active bookings or rentings"
                )
        
        # Update hotel
        query = """
        UPDATE "hotel chains".hotels 
        SET chainid = COALESCE(:chain_id, chainid),
            hname = COALESCE(:name, hname),
            haddress = COALESCE(:address, haddress),
            hemail = COALESCE(:email, hemail),
            hphone = COALESCE(:phone, hphone),
            num_of_rooms = COALESCE(:num_of_rooms, num_of_rooms),
            managerid = COALESCE(:manager_id, managerid)
        WHERE hotelid = :hotel_id
        """
        params = {**hotel_data, "hotel_id": hotel_id}
        result = db.execute(text(query), params)
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Hotel {hotel_id} not found")
        db.commit()
        return {"message": "Hotel updated successfully"}
    except HTTPException as e:
        db.rollback()
        raise e
    except Exception as e:
        db.rollback()
        logger.error(f"Error in update_hotel: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/hotels/{hotel_id}")
def delete_hotel(hotel_id: int, db = Depends(get_db)):
    try:
        # Check if hotel exists
        check_query = """
        SELECT hotelid FROM "hotel chains".hotels 
        WHERE hotelid = :hotel_id
        """
        result = db.execute(text(check_query), {"hotel_id": hotel_id})
        if not result.first():
            raise HTTPException(status_code=404, detail=f"Hotel {hotel_id} not found")
        
        # Check for active bookings or rentings
        check_active_query = """
        SELECT 
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM "hotel chains".bookings b
                    JOIN "hotel chains".rooms r ON b.roomid = r.roomid
                    WHERE r.hotelid = :hotel_id 
                    AND b.status IN ('Booked', 'CheckedIn')
                ) THEN true
                WHEN EXISTS (
                    SELECT 1 FROM "hotel chains".rentings rt
                    JOIN "hotel chains".rooms r ON rt.roomid = r.roomid
                    WHERE r.hotelid = :hotel_id 
                    AND rt.status = 'CheckedIn'
                ) THEN true
                ELSE false
            END as has_active
        """
        result = db.execute(text(check_active_query), {"hotel_id": hotel_id})
        if result.scalar():
            raise HTTPException(
                status_code=400, 
                detail="Cannot delete hotel with active bookings or rentings"
            )
        
        # Delete hotel
        query = 'DELETE FROM "hotel chains".hotels WHERE hotelid = :hotel_id'
        result = db.execute(text(query), {"hotel_id": hotel_id})
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Hotel {hotel_id} not found")
        db.commit()
        return {"message": "Hotel deleted successfully"}
    except HTTPException as e:
        db.rollback()
        raise e
    except Exception as e:
        db.rollback()
        logger.error(f"Error in delete_hotel: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/rooms/{room_id}")
def update_room(room_id: int, room_data: dict, db = Depends(get_db)):
    try:
        # Check if room exists
        check_query = """
        SELECT roomid FROM "hotel chains".rooms 
        WHERE roomid = :room_id
        """
        result = db.execute(text(check_query), {"room_id": room_id})
        if not result.first():
            raise HTTPException(status_code=404, detail=f"Room {room_id} not found")
        
        # Check if hotel exists if trying to change hotel
        if "hotel_id" in room_data:
            hotel_query = """
            SELECT hotelid FROM "hotel chains".hotels 
            WHERE hotelid = :hotel_id
            """
            result = db.execute(text(hotel_query), {"hotel_id": room_data["hotel_id"]})
            if not result.first():
                raise HTTPException(status_code=404, detail=f"Hotel {room_data['hotel_id']} not found")
        
        # Check for active bookings or rentings if trying to change hotel
        if "hotel_id" in room_data:
            check_active_query = """
            SELECT 
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM "hotel chains".bookings 
                        WHERE roomid = :room_id 
                        AND status IN ('Booked', 'CheckedIn')
                    ) THEN true
                    WHEN EXISTS (
                        SELECT 1 FROM "hotel chains".rentings 
                        WHERE roomid = :room_id 
                        AND status = 'CheckedIn'
                    ) THEN true
                    ELSE false
                END as has_active
            """
            result = db.execute(text(check_active_query), {"room_id": room_id})
            if result.scalar():
                raise HTTPException(
                    status_code=400, 
                    detail="Cannot change room's hotel while there are active bookings or rentings"
                )
        
        # Update room
        query = """
        UPDATE "hotel chains".rooms 
        SET hotelid = COALESCE(:hotel_id, hotelid),
            price = COALESCE(:price, price),
            capacity = COALESCE(:capacity, capacity),
            view_type = COALESCE(:view_type, view_type),
            extendable = COALESCE(:extendable, extendable),
            amenities = COALESCE(:amenities, amenities),
            damages = COALESCE(:damages, damages)
        WHERE roomid = :room_id
        """
        params = {**room_data, "room_id": room_id}
        result = db.execute(text(query), params)
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Room {room_id} not found")
        db.commit()
        return {"message": "Room updated successfully"}
    except HTTPException as e:
        db.rollback()
        raise e
    except Exception as e:
        db.rollback()
        logger.error(f"Error in update_room: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/rooms/{room_id}")
def delete_room(room_id: int, db = Depends(get_db)):
    try:
        # Check if room exists
        check_query = """
        SELECT roomid FROM "hotel chains".rooms 
        WHERE roomid = :room_id
        """
        result = db.execute(text(check_query), {"room_id": room_id})
        if not result.first():
            raise HTTPException(status_code=404, detail=f"Room {room_id} not found")
        
        # Check for active bookings or rentings
        check_active_query = """
        SELECT 
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM "hotel chains".bookings 
                    WHERE roomid = :room_id 
                    AND status IN ('Booked', 'CheckedIn')
                ) THEN true
                WHEN EXISTS (
                    SELECT 1 FROM "hotel chains".rentings 
                    WHERE roomid = :room_id 
                    AND status = 'CheckedIn'
                ) THEN true
                ELSE false
            END as has_active
        """
        result = db.execute(text(check_active_query), {"room_id": room_id})
        if result.scalar():
            raise HTTPException(
                status_code=400, 
                detail="Cannot delete room with active bookings or rentings"
            )
        
        # Delete room
        query = 'DELETE FROM "hotel chains".rooms WHERE roomid = :room_id'
        result = db.execute(text(query), {"room_id": room_id})
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Room {room_id} not found")
        db.commit()
        return {"message": "Room deleted successfully"}
    except HTTPException as e:
        db.rollback()
        raise e
    except Exception as e:
        db.rollback()
        logger.error(f"Error in delete_room: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/employees/{employee_id}")
def update_employee(employee_id: int, employee_data: dict, db = Depends(get_db)):
    try:
        # Check if employee exists
        check_query = """
        SELECT employeeid FROM "hotel chains".employees 
        WHERE employeeid = :employee_id
        """
        result = db.execute(text(check_query), {"employee_id": employee_id})
        if not result.first():
            raise HTTPException(status_code=404, detail=f"Employee {employee_id} not found")
        
        # Check if hotel exists if trying to change hotel
        if "hotel_id" in employee_data:
            hotel_query = """
            SELECT hotelid FROM "hotel chains".hotels 
            WHERE hotelid = :hotel_id
            """
            result = db.execute(text(hotel_query), {"hotel_id": employee_data["hotel_id"]})
            if not result.first():
                raise HTTPException(status_code=404, detail=f"Hotel {employee_data['hotel_id']} not found")
        
        # Check if employee is a manager and has active rentings if trying to change hotel
        if "hotel_id" in employee_data:
            check_manager_query = """
            SELECT 
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM "hotel chains".hotels 
                        WHERE managerid = :employee_id
                    ) THEN true
                    ELSE false
                END as is_manager
            """
            result = db.execute(text(check_manager_query), {"employee_id": employee_id})
            if result.scalar():
                raise HTTPException(
                    status_code=400, 
                    detail="Cannot change hotel for an employee who is a hotel manager"
                )
            
            check_active_query = """
            SELECT 
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM "hotel chains".rentings 
                        WHERE employeeid = :employee_id 
                        AND status = 'CheckedIn'
                    ) THEN true
                    ELSE false
                END as has_active
            """
            result = db.execute(text(check_active_query), {"employee_id": employee_id})
            if result.scalar():
                raise HTTPException(
                    status_code=400, 
                    detail="Cannot change hotel for an employee with active rentings"
                )
        
        # Update employee
        query = """
        UPDATE "hotel chains".employees 
        SET efirstname = COALESCE(:firstname, efirstname),
            elastname = COALESCE(:lastname, elastname),
            eaddress = COALESCE(:address, eaddress),
            hotelid = COALESCE(:hotel_id, hotelid),
            erole = COALESCE(:role, erole),
            ephone = COALESCE(:phone, ephone),
            eemail = COALESCE(:email, eemail),
            sin = COALESCE(:sin, sin)
        WHERE employeeid = :employee_id
        """
        params = {**employee_data, "employee_id": employee_id}
        result = db.execute(text(query), params)
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Employee {employee_id} not found")
        db.commit()
        return {"message": "Employee updated successfully"}
    except HTTPException as e:
        db.rollback()
        raise e
    except Exception as e:
        db.rollback()
        logger.error(f"Error in update_employee: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/employees/{employee_id}")
def delete_employee(employee_id: int, db = Depends(get_db)):
    try:
        # Check if employee exists
        check_query = """
        SELECT employeeid FROM "hotel chains".employees 
        WHERE employeeid = :employee_id
        """
        result = db.execute(text(check_query), {"employee_id": employee_id})
        if not result.first():
            raise HTTPException(status_code=404, detail=f"Employee {employee_id} not found")
        
        # Check if employee is a manager
        check_manager_query = """
        SELECT 
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM "hotel chains".hotels 
                    WHERE managerid = :employee_id
                ) THEN true
                ELSE false
            END as is_manager
        """
        result = db.execute(text(check_manager_query), {"employee_id": employee_id})
        if result.scalar():
            raise HTTPException(
                status_code=400, 
                detail="Cannot delete an employee who is a hotel manager"
            )
        
        # Check for active rentings
        check_active_query = """
        SELECT 
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM "hotel chains".rentings 
                    WHERE employeeid = :employee_id 
                    AND status = 'CheckedIn'
                ) THEN true
                ELSE false
            END as has_active
        """
        result = db.execute(text(check_active_query), {"employee_id": employee_id})
        if result.scalar():
            raise HTTPException(
                status_code=400, 
                detail="Cannot delete employee with active rentings"
            )
        
        # Delete employee
        query = 'DELETE FROM "hotel chains".employees WHERE employeeid = :employee_id'
        result = db.execute(text(query), {"employee_id": employee_id})
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Employee {employee_id} not found")
        db.commit()
        return {"message": "Employee deleted successfully"}
    except HTTPException as e:
        db.rollback()
        raise e
    except Exception as e:
        db.rollback()
        logger.error(f"Error in delete_employee: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

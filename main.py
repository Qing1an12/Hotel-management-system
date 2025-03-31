from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError
from pydantic import BaseModel, validator
from typing import List, Optional
import os
from dotenv import load_dotenv
from datetime import date, datetime
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
    hotel_category: Optional[int] = None
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

class BookingCreate(BaseModel):
    room_id: int
    customer_id: int
    start_date: date
    end_date: date

class RentingCreate(BaseModel):
    booking_id: Optional[int] = None
    room_id: int
    customer_id: int
    employee_id: int
    start_date: date
    end_date: date

@app.get("/api/hotel-chains")
def get_hotel_chains(db = Depends(get_db)):
    try:
        result = db.execute(text('SELECT * FROM hotelchains'))
        rows = []
        for row in result:
            row_dict = {}
            for idx, col in enumerate(result.keys()):
                row_dict[col] = row[idx]
            rows.append(row_dict)
        return rows
    except Exception as e:
        logger.error(f"Error in get_hotel_chains: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/hotels")
def get_hotels(chain_id: Optional[int] = None, category: Optional[int] = None, db = Depends(get_db)):
    try:
        query = 'SELECT * FROM hotels WHERE 1=1'
        params = {}
        if chain_id:
            query += " AND chainid = :chain_id"
            params['chain_id'] = chain_id
        if category:
            query += " AND category = :category"
            params['category'] = category
        result = db.execute(text(query), params)
        rows = []
        for row in result:
            row_dict = {}
            for idx, col in enumerate(result.keys()):
                row_dict[col] = row[idx]
            rows.append(row_dict)
        return rows
    except Exception as e:
        logger.error(f"Error in get_hotels: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/rooms/available")
async def get_available_rooms(
    start_date: str,
    end_date: str,
    capacity: Optional[int] = None,
    area: Optional[str] = None,
    hotel_chain: Optional[str] = None,
    hotel_category: Optional[int] = None,
    max_price: Optional[float] = None,
    db = Depends(get_db)
):
    try:
        # Validate dates
        try:
            start_date_obj = datetime.strptime(start_date, '%Y-%m-%d').date()
            end_date_obj = datetime.strptime(end_date, '%Y-%m-%d').date()
            
            if start_date_obj < date.today():
                raise HTTPException(status_code=400, detail="Start date cannot be in the past")
            
            if end_date_obj <= start_date_obj:
                raise HTTPException(status_code=400, detail="End date must be after start date")
        except ValueError as e:
            raise HTTPException(status_code=400, detail="Invalid date format. Please use YYYY-MM-DD")

        query = text("""
        SELECT 
            r.*,
            h.hname as hotel_name,
            hc.cname as chain_name,
            h.haddress as hotel_address,
            h.hemail as hotel_email,
            h.hphone as hotel_phone
        FROM rooms r
        JOIN hotels h ON r.hotelid = h.hotelid
        JOIN hotelchains hc ON h.chainid = hc.chainid
        WHERE r.roomid NOT IN (
            SELECT roomid FROM bookings
            WHERE startdate <= :end_date AND enddate >= :start_date
            UNION
            SELECT roomid FROM rentings
            WHERE startdate <= :end_date AND enddate >= :start_date
        )
        """)
        
        params = {
            "start_date": start_date_obj,
            "end_date": end_date_obj
        }
        
        conditions = []
        if capacity is not None:
            conditions.append("r.capacity = :capacity")
            params["capacity"] = capacity
        if area:
            conditions.append("r.area = :area")
            params["area"] = area
        if hotel_chain:
            conditions.append("hc.cname = :hotel_chain")
            params["hotel_chain"] = hotel_chain
        if hotel_category is not None:
            conditions.append("h.category = :hotel_category")
            params["hotel_category"] = hotel_category
        if max_price is not None:
            conditions.append("r.price <= :max_price")
            params["max_price"] = max_price
            
        if conditions:
            query = text(str(query) + " AND " + " AND ".join(conditions))
            
        logger.debug(f"Executing query: {query}")
        logger.debug(f"With parameters: {params}")
        
        result = db.execute(query, params)
        rows = []
        for row in result:
            row_dict = {}
            for idx, col in enumerate(result.keys()):
                row_dict[col] = row[idx]
            rows.append(row_dict)
            
        logger.debug(f"Found {len(rows)} available rooms")
        return rows
    except HTTPException as e:
        # Re-raise HTTP exceptions
        raise e
    except Exception as e:
        logger.error(f"Error in get_available_rooms: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/customers")
async def create_customer(customer: CustomerCreate, db = Depends(get_db)):
    try:
        # Validate customer data
        if not customer.firstname or not customer.lastname or not customer.address:
            raise HTTPException(status_code=400, detail="All fields are required")
            
        query = """
        INSERT INTO customers (firstname, lastname, address)
        VALUES (:firstname, :lastname, :address)
        RETURNING customerid
        """
        
        params = {
            "firstname": customer.firstname,
            "lastname": customer.lastname,
            "address": customer.address
        }
        
        logger.debug(f"Creating customer with params: {params}")
        result = db.execute(text(query), params)
        customer_id = result.scalar()
        db.commit()
        
        logger.debug(f"Created customer with ID: {customer_id}")
        return {"customerid": customer_id}
    except SQLAlchemyError as e:
        db.rollback()
        logger.error(f"Database error in create_customer: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    except HTTPException as e:
        raise e
    except Exception as e:
        db.rollback()
        logger.error(f"Error in create_customer: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/bookings")
def create_booking(booking: BookingCreate, db = Depends(get_db)):
    try:
        # Check if room exists and get its hotelid
        room_query = 'SELECT hotelid FROM rooms WHERE roomid = :room_id'
        result = db.execute(text(room_query), {"room_id": booking.room_id})
        room = result.first()
        if not room:
            raise HTTPException(status_code=404, detail="Room not found")
        
        # Create the booking
        query = """
        INSERT INTO bookings (roomid, hotelid, customerid, start_date, end_date)
        VALUES (:room_id, :hotel_id, :customer_id, :start_date, :end_date)
        RETURNING bookingid
        """
        params = {
            **booking.dict(),
            "hotel_id": room[0]
        }
        result = db.execute(text(query), params)
        db.commit()
        return {"bookingid": result.scalar()}
    except Exception as e:
        db.rollback()
        logger.error(f"Error in create_booking: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/rentings")
def create_renting(renting: RentingCreate, db = Depends(get_db)):
    try:
        # Check if room exists and get its hotelid
        room_query = 'SELECT hotelid FROM rooms WHERE roomid = :room_id'
        result = db.execute(text(room_query), {"room_id": renting.room_id})
        room = result.first()
        if not room:
            raise HTTPException(status_code=404, detail="Room not found")
        
        # Create the renting
        query = """
        INSERT INTO rentings (rentingid, roomid, hotelid, customerid, employeeid, start_date, end_date, status)
        VALUES (:booking_id, :room_id, :hotel_id, :customer_id, :employee_id, :start_date, :end_date, 'CheckedIn')
        RETURNING rentingid
        """
        params = {
            **renting.dict(),
            "hotel_id": room[0]
        }
        result = db.execute(text(query), params)
        db.commit()
        return {"rentingid": result.scalar()}
    except Exception as e:
        db.rollback()
        logger.error(f"Error in create_renting: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/employees")
def get_employees(hotel_id: Optional[int] = None, db = Depends(get_db)):
    try:
        query = 'SELECT * FROM employees WHERE 1=1'
        params = {}
        if hotel_id:
            query += " AND hotelid = :hotel_id"
            params["hotel_id"] = hotel_id
        result = db.execute(text(query), params)
        rows = []
        for row in result:
            row_dict = {}
            for idx, col in enumerate(result.keys()):
                row_dict[col] = row[idx]
            rows.append(row_dict)
        return rows
    except Exception as e:
        logger.error(f"Error in get_employees: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/customers/{customer_id}/bookings")
def get_customer_bookings(customer_id: int, db = Depends(get_db)):
    try:
        query = 'SELECT * FROM bookings WHERE customerid = :customer_id'
        result = db.execute(text(query), {"customer_id": customer_id})
        rows = []
        for row in result:
            row_dict = {}
            for idx, col in enumerate(result.keys()):
                row_dict[col] = row[idx]
            rows.append(row_dict)
        return rows
    except Exception as e:
        logger.error(f"Error in get_customer_bookings: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/customers/{customer_id}/rentings")
def get_customer_rentings(customer_id: int, db = Depends(get_db)):
    try:
        query = 'SELECT * FROM rentings WHERE customerid = :customer_id'
        result = db.execute(text(query), {"customer_id": customer_id})
        rows = []
        for row in result:
            row_dict = {}
            for idx, col in enumerate(result.keys()):
                row_dict[col] = row[idx]
            rows.append(row_dict)
        return rows
    except Exception as e:
        logger.error(f"Error in get_customer_rentings: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Additional endpoints for management
@app.put("/api/customers/{customer_id}")
def update_customer(customer_id: int, customer: CustomerCreate, db = Depends(get_db)):
    try:
        query = """
        UPDATE customers 
        SET firstname = :firstname, lastname = :lastname, address = :address
        WHERE customerid = :customer_id
        """
        params = {**customer.dict(), "customer_id": customer_id}
        db.execute(text(query), params)
        db.commit()
        return {"message": "Customer updated successfully"}
    except Exception as e:
        db.rollback()
        logger.error(f"Error in update_customer: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/customers/{customer_id}")
def delete_customer(customer_id: int, db = Depends(get_db)):
    try:
        query = 'DELETE FROM customers WHERE customerid = :customer_id'
        db.execute(text(query), {"customer_id": customer_id})
        db.commit()
        return {"message": "Customer deleted successfully"}
    except Exception as e:
        db.rollback()
        logger.error(f"Error in delete_customer: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# SQL Views endpoints
@app.get("/api/views/room-capacity")
def get_room_capacity_view(db = Depends(get_db)):
    try:
        query = """
        SELECT h.name as hotel_name, COUNT(*) as total_rooms,
               SUM(CASE WHEN r.capacity = 1 THEN 1 ELSE 0 END) as single_rooms,
               SUM(CASE WHEN r.capacity = 2 THEN 1 ELSE 0 END) as double_rooms,
               SUM(CASE WHEN r.capacity = 3 THEN 1 ELSE 0 END) as triple_rooms,
               SUM(CASE WHEN r.capacity >= 4 THEN 1 ELSE 0 END) as other_rooms
        FROM hotels h
        JOIN rooms r ON h.hotelid = r.hotelid
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
        FROM hotels h
        JOIN rooms r ON h.hotelid = r.hotelid
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

# Additional endpoints for hotel and room management
@app.put("/api/hotels/{hotel_id}")
def update_hotel(hotel_id: int, hotel_data: dict, db = Depends(get_db)):
    try:
        query = """
        UPDATE hotels 
        SET chainid = :chain_id, category = :category, name = :name
        WHERE hotelid = :hotel_id
        """
        params = {**hotel_data, "hotel_id": hotel_id}
        db.execute(text(query), params)
        db.commit()
        return {"message": "Hotel updated successfully"}
    except Exception as e:
        db.rollback()
        logger.error(f"Error in update_hotel: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/hotels/{hotel_id}")
def delete_hotel(hotel_id: int, db = Depends(get_db)):
    try:
        query = 'DELETE FROM hotels WHERE hotelid = :hotel_id'
        db.execute(text(query), {"hotel_id": hotel_id})
        db.commit()
        return {"message": "Hotel deleted successfully"}
    except Exception as e:
        db.rollback()
        logger.error(f"Error in delete_hotel: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/rooms/{room_id}")
def update_room(room_id: int, room_data: dict, db = Depends(get_db)):
    try:
        query = """
        UPDATE rooms 
        SET hotelid = :hotel_id, price = :price, capacity = :capacity, area = :area
        WHERE roomid = :room_id
        """
        params = {**room_data, "room_id": room_id}
        db.execute(text(query), params)
        db.commit()
        return {"message": "Room updated successfully"}
    except Exception as e:
        db.rollback()
        logger.error(f"Error in update_room: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/rooms/{room_id}")
def delete_room(room_id: int, db = Depends(get_db)):
    try:
        query = 'DELETE FROM rooms WHERE roomid = :room_id'
        db.execute(text(query), {"room_id": room_id})
        db.commit()
        return {"message": "Room deleted successfully"}
    except Exception as e:
        db.rollback()
        logger.error(f"Error in delete_room: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Employee management endpoints
@app.put("/api/employees/{employee_id}")
def update_employee(employee_id: int, employee_data: dict, db = Depends(get_db)):
    try:
        query = """
        UPDATE employees 
        SET name = :name, hotelid = :hotel_id
        WHERE employeeid = :employee_id
        """
        params = {**employee_data, "employee_id": employee_id}
        db.execute(text(query), params)
        db.commit()
        return {"message": "Employee updated successfully"}
    except Exception as e:
        db.rollback()
        logger.error(f"Error in update_employee: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/employees/{employee_id}")
def delete_employee(employee_id: int, db = Depends(get_db)):
    try:
        query = 'DELETE FROM employees WHERE employeeid = :employee_id'
        db.execute(text(query), {"employee_id": employee_id})
        db.commit()
        return {"message": "Employee deleted successfully"}
    except Exception as e:
        db.rollback()
        logger.error(f"Error in delete_employee: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

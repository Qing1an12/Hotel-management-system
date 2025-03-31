from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

load_dotenv()

# Database connection
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise ValueError("DATABASE_URL environment variable is not set")

engine = create_engine(DATABASE_URL)

with engine.connect() as conn:
    # Set search path
    conn.execute(text('SET search_path TO "hotel chains", public'))
    
    # Check hotels table
    result = conn.execute(text("""
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = 'hotel chains' 
        AND table_name = 'hotels'
    """))
    print("\nHotels table columns:")
    for row in result:
        print(f"- {row[0]}: {row[1]}")
    
    # Check hotelchains table
    result = conn.execute(text("""
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = 'hotel chains' 
        AND table_name = 'hotelchains'
    """))
    print("\nHotelChains table columns:")
    for row in result:
        print(f"- {row[0]}: {row[1]}")

from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv
import subprocess

def setup_database():
    load_dotenv()
    
    # First connect to default 'postgres' database to create our database
    base_url = os.getenv("DATABASE_URL").rsplit('/', 1)[0]
    engine = create_engine(f"{base_url}/postgres")
    
    try:
        # Create database if it doesn't exist
        with engine.connect() as conn:
            conn.execute(text("COMMIT"))  # Close any open transactions
            
            # Force close all connections to the database
            conn.execute(text("""
                SELECT pg_terminate_backend(pg_stat_activity.pid)
                FROM pg_stat_activity
                WHERE pg_stat_activity.datname = 'hotel_chains'
                AND pid <> pg_backend_pid();
            """))
            
            conn.execute(text("DROP DATABASE IF EXISTS hotel_chains"))
            conn.execute(text("CREATE DATABASE hotel_chains"))
            print("Database 'hotel_chains' created successfully!")
    except Exception as e:
        print(f"Error creating database: {str(e)}")
        return

    # Now use psql to import the schema since it handles the dump format correctly
    db_url = os.getenv("DATABASE_URL")
    host = "localhost"
    dbname = "hotel_chains"
    user = "postgres"
    password = ""  # No password since we're using trust authentication
    
    try:
        # Use psql to import the schema
        cmd = f'"C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe" -h {host} -d {dbname} -U {user} -f CSI2132HOTELSDBTriggers.sql'
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        if result.returncode == 0:
            print("Schema imported successfully!")
        else:
            print(f"Error importing schema: {result.stderr}")
            
        # Connect to verify tables
        engine = create_engine(db_url)
        with engine.connect() as conn:
            # Verify tables were created
            result = conn.execute(text("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'hotel chains'
            """))
            tables = result.fetchall()
            print("\nCreated tables:")
            for table in tables:
                print(f"- {table[0]}")
                
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    setup_database()

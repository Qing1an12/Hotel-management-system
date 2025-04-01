import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

# Load environment variables
load_dotenv()

# Get database URL
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise ValueError("DATABASE_URL environment variable is not set")

# Create engine
engine = create_engine(DATABASE_URL)

# Read schema file
with open('schema.sql', 'r') as f:
    schema_sql = f.read()

# Execute schema
with engine.connect() as conn:
    conn.execute(text("DROP SCHEMA IF EXISTS \"hotel chains\" CASCADE;"))
    conn.execute(text(schema_sql))
    conn.commit()

print("Schema updated successfully!")

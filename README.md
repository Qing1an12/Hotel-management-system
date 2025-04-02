# Hotel Chains Management System

A web application for managing hotel chains, hotels, rooms, bookings, and rentings.

## Features

- User authentication (customers and employees)
- Real-time room availability search with multiple criteria
- Room booking and rental management
- Hotel and room management for employees
- Customer management
- Payment processing

## Tech Stack

- Backend: Python FastAPI
- Frontend: HTML, CSS, JavaScript
- Database: PostgreSQL

## Setup Instructions

### 1. Prerequisites

- Python 3.8 or higher
- PostgreSQL 17
- Git

### 2. Clone the Repository

```bash
git clone https://github.com/Qing1an12/Hotel-management-system.git
cd Hotel-management-system
```

### 3. Set Up PostgreSQL Database

1. Install PostgreSQL 17 if not already installed
2. Make sure PostgreSQL service is running
3. Create a database user with these default credentials:
   - Username: postgres
   - Password: admin
4. Run the database setup script:
```bash
# On Windows
"C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -d postgres -f CSI2132HOTELSDB.sql

# On Mac/Linux
psql -U postgres -d postgres -f CSI2132HOTELSDB.sql
```

### 4. Install Python Dependencies

```bash
pip install fastapi uvicorn sqlalchemy psycopg2-binary python-dotenv
```

### 5. Set Environment Variables

Create a `.env` file in the project root or set the environment variable:

```bash
# Windows PowerShell
$env:DATABASE_URL="postgresql://postgres:admin@localhost:5432/postgres"

# Windows CMD
set DATABASE_URL=postgresql://postgres:admin@localhost:5432/postgres

# Mac/Linux
export DATABASE_URL=postgresql://postgres:admin@localhost:5432/postgres
```

### 6. Run the Application

```bash
# Start the server
uvicorn main:app --reload
```

The application will be available at:
- Main application: http://localhost:8000
- API documentation: http://localhost:8000/docs

## Common Issues

1. If you see "Tables in 'hotel chains' schema: []", make sure you've run the SQL setup script correctly.
2. If you get database connection errors, check that:
   - PostgreSQL is running
   - Your database credentials match
   - The DATABASE_URL environment variable is set correctly

## Development

To make changes:
1. Create a new branch
2. Make your changes
3. Test thoroughly
4. Create a pull request

## Support

If you encounter any issues, please:
1. Check the common issues section above
2. Review the error messages in the console
3. Contact the development team

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
- Frontend: React with TypeScript
- Database: PostgreSQL

## Setup

1. Install Python dependencies:
```bash
pip install -r requirements.txt
```

2. Install Node.js dependencies (in the frontend directory):
```bash
cd frontend
npm install
```

3. Set up environment variables in `.env`

4. Run the backend:
```bash
uvicorn main:app --reload
```

5. Run the frontend:
```bash
cd frontend
npm start
```

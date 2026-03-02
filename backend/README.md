# Way2Sustain Backend - Step by Step Guide

## Prerequisites

- Python 3.8 or higher installed

---

## Quick Start (If Backend is NOT Running)

### Step 1: Navigate to Project Root

```
cd c:\ws\Way2Sustain
```

Or on Linux/Mac:
```
cd /path/to/Way2Sustain
```

### Step 2: Install Dependencies (if not already installed)

```
pip install -r backend/requirements.txt
```

### Step 3: Run the Server

```
uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```

The server will start at:
- **API**: http://localhost:8000
- **Interactive Docs**: http://localhost:8000/docs

---

## Testing the API

### Using Interactive Docs (Recommended)

1. Open http://localhost:8000/docs in your browser
2. Click on any endpoint to expand it
3. Click "Try it out" button
4. Fill in the parameters and click "Execute"

---

### Using Command Line (curl)

#### 1. Register a New User

```
bash
curl -X POST "http://localhost:8000/register" \
  -H "Content-Type: application/json" \
  -d '{"username": "john", "email": "john@example.com", "name": "John Doe", "password": "password123"}'
```

#### 2. Login

```
bash
curl -X POST "http://localhost:8000/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "john@example.com", "password": "password123"}'
```

**Response:**
```
json
{
  "status": "success",
  "access_token": "eyJhbGc...",
  "token_type": "bearer",
  "user": {...}
}
```

**Copy the `access_token` value** for subsequent requests.

#### 3. Add a Trip (Eco Route)

Replace `YOUR_TOKEN_HERE` with your actual access token:

```
bash
curl -X POST "http://localhost:8000/trip/add" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "distance": 10.5,
    "duration": 25.0,
    "route_type": "eco",
    "start_location": "Home",
    "end_location": "Office"
  }'
```

**Response:**
```
json
{
  "id": 1,
  "user_id": 1,
  "distance": 10.5,
  "duration": 25.0,
  "co2_saved": 2.205,
  "eco_points": 105.0,
  "route_type": "eco",
  ...
}
```

#### 4. Get Dashboard

```
bash
curl -X GET "http://localhost:8000/user/1/dashboard" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

#### 5. Get Profile

```
bash
curl -X GET "http://localhost:8000/user/1/profile" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

#### 6. Get Trip History

```
bash
curl -X GET "http://localhost:8000/trip/1/trips" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

#### 7. Get Leaderboard

```
bash
curl -X GET "http://localhost:8000/leaderboard"
```

---

## Eco Points Calculation

| Route Type | Points per KM |
|------------|---------------|
| eco        | 10 points     |
| balanced   | 5 points      |
| normal     | 0 points      |

**CO2 Saved**: 0.21 kg per km (assuming electric vehicle)

---

## API Endpoints Summary

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/register` | Register new user |
| POST | `/login` | Login and get JWT token |
| POST | `/trip/add` | Add completed trip |
| GET | `/user/{id}/dashboard` | Get dashboard data |
| GET | `/user/{id}/profile` | Get user profile |
| GET | `/trip/{id}/trips` | Get user's trip history |
| GET | `/leaderboard` | Get full leaderboard |
| GET | `/leaderboard/{id}` | Get user's rank |

---

## Connecting Flutter App

Update your Flutter app's API configuration to point to your backend:

For Android Emulator: `http://10.0.2.2:8000`
For iOS Simulator: `http://localhost:8000`
For Physical Device: Use your computer's IP address

---

## Troubleshooting

### Port Already in Use

If port 8000 is busy, run on a different port:

```
bash
uvicorn backend.main:app --host 0.0.0.0 --port 8001 --reload
```

### Database Issues

Delete the SQLite database to reset:

```
bash
del way2sustain.db
```

Then restart the server - it will create a new database automatically.

# Way2Sustain - Technical Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Frontend Components](#frontend-components)
4. [Backend Components](#backend-components)
5. [Algorithms](#algorithms)
6. [Data Models](#data-models)
7. [API Integration](#api-integration)
8. [Configuration](#configuration)

---

## 1. Project Overview

**Way2Sustain** is a sustainable travel application that helps users plan eco-friendly routes by combining:
- **Ant Colony Optimization (ACO)** algorithm for intelligent route generation
- Real-time environmental data (weather, air quality, traffic)
- 5-day future predictions for route planning
- Eco points gamification system to encourage sustainable travel

**Technology Stack:**
- **Frontend:** Flutter (Dart)
- **Backend:** Python FastAPI
- **Database:** SQLite
- **APIs:** OSRM, OpenWeatherMap, OpenChargeMap, Nominatim

---

## 2. Architecture

### 2.1 System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP (Mobile)                         │
├─────────────────────────────────────────────────────────────────────┤
│  Screens          │  Services           │  Models      │ Algorithms │
│  ─────────        │  ────────           │  ──────      │ ───────── │
│  - Splash         │  - RouteService     │  - RouteData │  - ACO    │
│  - Login          │  - AuthService      │  - RouteOpt  │  - EcoPts  │
│  - Home           │  - EcoPointsService│  - User      │           │
│  - SelectLocation│  - LocationService │              │           │
│  - RouteSelection│  - EnvDataService   │              │           │
│  - Profile        │  - PredictionService│             │           │
└────────┬──────────────────────────────────────┬──────────────────────┘
         │              HTTP/REST API              │
         ▼                                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      FASTAPI BACKEND (Python)                        │
├─────────────────────────────────────────────────────────────────────┤
│  Routers             │  ACO Engine          │  Services             │
│  ───────             │  ──────────          │  ────────             │
│  - /auth             │  - ACOOptimizer      │  - PredictionService │
│  - /users            │  - ACO Core          │  - EnvCostCalculator  │
│  - /trips            │  - OSRM Connector   │  - RouteService      │
│  - /leaderboard      │                      │                      │
│  - /routes           │                      │                      │
└────────┬──────────────────────────────────────┬──────────────────────┘
         │                                      │
         ▼                                      ▼
┌─────────────────────┐              ┌─────────────────────────────┐
│   SQLite Database   │              │     External APIs            │
│   ─────────────     │              │     ─────────────            │
│   - Users           │              │     - OSRM (Routing)         │
│   - Trips           │              │     - OpenWeatherMap (Weather│
│                     │              │     - OpenChargeMap (EV)     │
│                     │              │     - Nominatim (Geocoding)  │
└─────────────────────┘              └─────────────────────────────┘
```

---

## 3. Frontend Components

### 3.1 Splash Screen

**Page Name:** Splash Screen

**Objective:** Display app branding while initializing services and checking authentication status.

**Core Functionality:**
1. Display app logo and branding
2. Initialize authentication service
3. Test backend connection
4. Check stored user session
5. Navigate to appropriate screen (Login or Home)

**Data Used:**
- App version
- Authentication token
- User session data

**Data Source:** Local storage, AuthService API

**Inputs:** None (auto-initialization)

**Outputs:**
- Navigation to `/login` or `/home`
- User authentication state

---

### 3.2 Login Page

**Page Name:** Login Screen

**Objective:** Authenticate users with email/password or allow guest access.

**Core Functionality:**
1. Email/password input validation
2. Email/password authentication via API
3. Google login placeholder (future feature)
4. Facebook login placeholder (future feature)
5. Guest login option
6. Password visibility toggle
7. Forgot password flow
8. Privacy policy and terms display

**Data Used:**
| Field | Type | Description |
|-------|------|-------------|
| email | String | User email address |
| password | String | User password |
| isGuest | Boolean | Guest mode flag |

**Data Source:** `POST /login` API endpoint

**Inputs:**
- Email input
- Password input
- Login button press
- Forgot password link click
- Sign up link click

**Outputs:**
- Authentication token
- User profile data
- Navigation to home page

**Privacy Policy Content:**
```
1. Data Collection: Location, device info, route preferences
2. Use of Data: Route calculation, emissions estimation, AI models
3. Data Storage: Secure storage, no third-party sharing
4. User Rights: Data deletion, location tracking disable
```

---

### 3.3 Home Page

**Page Name:** Home Dashboard

**Objective:** Display user dashboard with eco-stats, weather, air quality, and navigation to route planning.

**Core Functionality:**
1. Display current location weather
2. Display air quality index (AQI)
3. Show user eco-points and statistics
4. Interactive map with current location
5. Quick access to route planning
6. Leaderboard preview
7. Carbon savings tracking

**Data Used:**
| Field | Type | Description |
|-------|------|-------------|
| totalTrips | Integer | Total trips completed |
| ecoPoints | Float | User's eco points |
| co2Saved | Float | CO2 saved in kg |
| rank | Integer | Leaderboard rank |
| weatherData | Object | Current weather |
| airQualityData | Object | Current AQI |

**Data Source:** 
- OpenWeatherMap API (weather, AQI)
- EcoPointsService API (user stats)

**Inputs:**
- Location permission
- Pull-to-refresh gesture
- Location refresh button

**Outputs:**
- Weather display (temperature, description, icon)
- AQI display with color coding
- Navigation to location selection

**Weather Display Algorithm:**
```
1. Get device location or fallback to default (Palakkad)
2. Call OpenWeatherMap API with coordinates
3. Parse response for temperature, humidity, wind
4. Map weather ID to icon (clear, clouds, rain, etc.)
5. Display with temperature-based color coding
```

**AQI Color Coding:**
- AQI 1 (Good): 🟢 Green
- AQI 2 (Fair): 🟢 Light Green
- AQI 3 (Moderate): 🟡 Yellow
- AQI 4 (Poor): 🟠 Orange
- AQI 5 (Very Poor): 🔴 Red

---

### 3.4 Select Location Page

**Page Name:** Location Selection Screen

**Objective:** Allow users to input origin and destination for route planning.

**Core Functionality:**
1. Origin location input with autocomplete
2. Destination location input with autocomplete
3. Location swap functionality
4. Map-based location selection
5. Current location detection
6. Travel mode selection
7. Date/time selection for predictions
8. Route finding button

**Data Used:**
| Field | Type | Description |
|-------|------|-------------|
| fromLocation | LatLng | Origin coordinates |
| toLocation | LatLng | Destination coordinates |
| selectedTravelMode | String | Vehicle type |
| fromSuggestions | List | Origin autocomplete results |
| toSuggestions | List | Destination autocomplete results |

**Data Source:** 
- Nominatim API (geocoding/autocomplete)
- Local fallback locations
- Geolocator (current location)

**Inputs:**
- Text input for locations
- Map tap for location
- Current location button
- Swap button
- Travel mode selection

**Outputs:**
- Validated origin/destination coordinates
- Travel mode selection
- Navigation to Route Selection Screen

**Autocomplete Algorithm:**
```
1. On text change, debounce for 300ms
2. Check local predefined locations first
3. If no match, call Nominatim API
4. Parse API response for name, lat, lon
5. Display in dropdown list
6. On selection, update coordinates
```

---

### 3.5 Route Selection Screen

**Page Name:** Route Options Screen

**Objective:** Display and compare multiple route options with environmental impact data.

**Core Functionality:**
1. Fetch routes from backend (ACO algorithm)
2. Display three route types:
   - **ECO CHAMPION**: Most environmentally friendly
   - **BALANCED**: Best compromise
   - **QUICKEST**: Fastest route
3. Show environmental metrics for each route
4. 5-day prediction forecast panel
5. EV charging station display (for electric vehicles)
6. Interactive map with route polylines
7. Route selection and navigation

**Data Used:**
| Field | Type | Description |
|-------|------|-------------|
| routeOptions | List[RouteOption] | Three route choices |
| selectedRoute | RouteOption | Currently selected route |
| predictions | List[DayPrediction] | 5-day forecast |
| evChargers | List | Nearby EV stations |

**Data Source:** 
- Backend API `/api/routes/calculate`
- PredictionService API
- EnvironmentalDataService (EV chargers)

**Inputs:**
- Route card tap
- Date picker
- Map zoom/pan
- Satellite toggle
- Select button

**Outputs:**
- Selected route data
- Navigation to result page

**Route Sorting Algorithm:**
```
1. Get all route options from API
2. Validate and filter invalid coordinates
3. Sort by: ECO CHAMPION → BALANCED → QUICKEST
4. Return sorted list for display
```

---

### 3.6 Route Result Page

**Page Name:** Route Result Screen

**Objective:** Display final route details and enable trip saving.

**Core Functionality:**
1. Display route on map
2. Show route details (distance, time)
3. Display eco-points earned
4. CO2 savings visualization
5. Save trip functionality
6. Share route option
7. Start navigation prompt

**Data Used:**
| Field | Type | Description |
|-------|------|-------------|
| from | String | Origin name |
| to | String | Destination name |
| vehicle | String | Vehicle type |
| ecoPoints | Integer | Points earned |
| routeData | RouteData | Route details |
| routeType | String | Route classification |
| routeColor | Color | Visual indicator |

**Data Source:** RouteSelectionScreen pass-through

**Inputs:**
- Save trip button
- Share button
- Back navigation

**Outputs:**
- Trip saved confirmation
- Eco-points updated

---

### 3.7 Profile Page

**Page Name:** User Profile Screen

**Objective:** Display user information and eco-statistics.

**Core Functionality:**
1. Display user name and email
2. Show eco-points breakdown
3. Display total statistics
4. Edit profile option
5. Logout functionality

**Data Used:**
| Field | Type | Description |
|-------|------|-------------|
| username | String | User display name |
| email | String | User email |
| ecoPoints | Float | Total eco points |
| totalTrips | Integer | Trips completed |
| totalKm | Float | Total kilometers |
| totalCO2Saved | Float | CO2 saved in kg |

**Data Source:** AuthService, EcoPointsService APIs

---

### 3.8 Leaderboard Page

**Page Name:** Leaderboard Screen

**Objective:** Display user rankings based on eco-points.

**Core Functionality:**
1. Fetch top users from API
2. Display rankings with points
3. Show current user position highlight
4. Pull-to-refresh functionality

**Data Source:** `/api/leaderboard` endpoint

---

### 3.9 My Trips Page

**Page Name:** Trip History Screen

**Objective:** Display user's completed trips.

**Core Functionality:**
1. List all past trips
2. Show trip details (date, distance, points)
3. Trip statistics summary

**Data Source:** `/api/trips` endpoint

---

### 3.10 Settings Page

**Page Name:** Settings Screen

**Objective:** Application configuration and preferences.

**Core Functionality:**
1. Language selection
2. Notification preferences
3. Privacy settings
4. About section

---

## 4. Backend Components

### 4.1 Main API (FastAPI)

**Endpoint:** `/`

**Objective:** Root API entry point providing service information.

**Core Functionality:**
1. Health check endpoint
2. Route calculation endpoints
3. User management endpoints
4. Trip tracking endpoints

**API Endpoints:**

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Root info |
| GET | `/health` | Health check |
| POST | `/api/routes/calculate` | Calculate routes with ACO |
| POST | `/api/routes/predict` | 5-day route prediction |
| POST | `/api/predictions` | Get environmental predictions |
| POST | `/auth/register` | User registration |
| POST | `/auth/login` | User authentication |
| GET | `/users/me` | Get current user |
| GET | `/trips` | Get user trips |
| POST | `/trips` | Create new trip |
| GET | `/leaderboard` | Get leaderboard |

---

### 4.2 ACO Optimizer

**File:** `backend/aco/aco_optimizer.py`

**Objective:** Generate optimized routes using Ant Colony Optimization algorithm.

**Core Functionality:**
1. Generate candidate waypoints between origin and destination
2. Run ACO iterations with multiple ants
3. Calculate fitness for each route
4. Integrate with OSRM for real route drawing
5. Calculate environmental metrics

**ACO Algorithm Pseudocode:**

```
ALGORITHM: ACO Route Optimization
─────────────────────────────────
INPUT: start_location, end_location, vehicle_type, route_type
OUTPUT: Optimized route with waypoints and metrics

1. INITIALIZE:
   - Set number of ants: ANT_COUNT = 20
   - Set iterations: MAX_ITERATIONS = 15
   - Set pheromone importance: ALPHA = 1.0
   - Set heuristic importance: BETA = 2.5
   - Set evaporation rate: EVAPORATION = 0.4

2. FOR EACH ITERATION (1 to MAX_ITERATIONS):
   a. FOR EACH ANT (1 to ANT_COUNT):
      i.   Generate candidate waypoints using route_type variations
      ii.  Build path through waypoints using probability selection
      iii. Calculate edge costs (distance, road type, traffic, AQI)
      iv.  Calculate fitness for complete path
      v.   Store best ant if fitness improves
   
   b. EVAPORATE pheromones:
      - For each edge: pheromone *= (1 - EVAPORATION)
      - Clamp minimum pheromone to 0.1
   
   c. DEPOSIT pheromones:
      - For best ants: deposit = Q / fitness
      - Update pheromone levels on traversed edges

3. RETURN best ant's waypoints

4. DRAW ROUTE using OSRM through waypoints

5. CALCULATE environmental metrics:
   - CO2 emissions
   - Eco points
   - Traffic level
   - Air quality

6. RETURN complete route with all metrics
```

**Waypoint Generation Algorithm:**

```
ALGORITHM: Generate Candidate Waypoints
──────────────────────────────────────
INPUT: start, end, count, route_type
OUTPUT: List of candidate waypoints

1. Calculate direction vector from start to end
2. Calculate perpendicular vector for offset

3. SET route_type parameters:
   - eco: offset_km = 15.0, random_factor = 0.5
   - balanced: offset_km = 6.0, random_factor = 0.3
   - quickest: offset_km = 0.5, random_factor = 0.05

4. FOR each waypoint (i = 1 to count):
   a. Calculate progress factor: t = i / (count + 1)
   b. Calculate base position along direct line
   c. Apply curve offset based on route_type:
      - eco: sin(t * π) curve
      - balanced: (1 - cos(t * π)) / 2 curve
      - quickest: minimal curve
   d. Add random variation
   e. Estimate road type based on position
   f. Create waypoint with coordinates

5. RETURN waypoints
```

---

### 4.3 Environmental Cost Module

**File:** `backend/aco/environmental_cost.py`

**Objective:** Calculate environmental costs for route evaluation.

**Route Weight Definitions:**

```
python
ROUTE_WEIGHTS = {
    'eco': RouteWeights(
        emission_weight=0.6,    # 60% - Prioritize low emissions
        distance_weight=0.3,     # 30%
        time_weight=0.1,         # 10%
    ),
    'balanced': RouteWeights(
        emission_weight=0.33,    # 33%
        distance_weight=0.33,    # 33%
        time_weight=0.34,        # 34%
    ),
    'quickest': RouteWeights(
        emission_weight=0.1,     # 10%
        distance_weight=0.2,     # 20%
        time_weight=0.7,         # 70% - Prioritize speed
    ),
}
```

**Vehicle Emission Factors (grams CO2 per km):**

```
python
BASE_EMISSIONS = {
    'walking': 0.0,
    'bicycle': 0.0,
    'electric car': 50.0,
    'hybrid car': 80.0,
    'petrol car': 120.0,
    'diesel car': 140.0,
}
```

**Fitness Calculation Equation:**

```
fitness = (distance_weight × normalized_distance) + 
           (time_weight × normalized_time) + 
           (emission_weight × normalized_emission) + 
           traffic_penalty + AQI_penalty

Where:
- normalized_distance = total_distance / 50000
- normalized_time = total_time / 3600
- normalized_emission = total_emission / 5.0
- traffic_penalty = avg_traffic × 0.15
- AQI_penalty = (avg_aqi / 300) × 0.20
```

**Explanation:** The fitness function combines multiple factors to evaluate route quality. Lower fitness values indicate better routes. The weights are adjusted based on route type (eco, balanced, quickest) to prioritize different aspects.

**Edge Cost Computation:**

```
edge_cost = (emission_weight × emission_kg × 100 +
            distance_weight × length × 0.01 +
            time_weight × travel_time × 0.1) × road_multiplier

Where road_multiplier varies by road type:
- motorway: 3.0
- primary: 2.5
- secondary: 2.0
- tertiary: 1.5
- residential: 0.5
- footway: 0.2
```

---

### 4.4 Prediction Service

**File:** `backend/aco/prediction_service.py`

**Objective:** Generate 5-day forecasts for traffic, AQI, weather, and EV availability.

**Prediction Algorithm:**

```
ALGORITHM: 5-Day Route Prediction
──────────────────────────────────
INPUT: start_lat, start_lng, end_lat, end_lng, vehicle_type, num_days
OUTPUT: List of daily predictions

1. Calculate base distance using Haversine formula

2. FOR each day (1 to num_days):
   a. Get day of week
   b. Determine if weekend
   c. Calculate traffic multiplier:
      - Weekday: 1.2 (higher traffic)
      - Weekend: 0.8 (lower traffic)
   
   d. Generate prediction values with random variation:
      - traffic_level: base × multiplier ± 0.1
      - aqi: base ± 20-30
      - weather_impact: base ± 0.1-0.15
      - co2_emission: base ± 10-15
      - ev_availability: 0.7 ± 0.2

3. RETURN predictions list
```

---

### 4.5 Database Models

**User Model:**
```
python
class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(unique=True, index=True)
    email: str = Field(unique=True, index=True)
    hashed_password: str
    name: str = Field(default="")
    
    # Eco statistics
    eco_points: float = Field(default=0.0)
    total_trips: int = Field(default=0)
    total_km: float = Field(default=0.0)
    total_co2_saved: float = Field(default=0.0)
    
    created_at: datetime = Field(default_factory=datetime.utcnow)
```

**Trip Model:**
```
python
class Trip(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id")
    
    # Trip details
    distance: float = Field(default=0.0)  # km
    duration: float = Field(default=0.0)  # minutes
    co2_saved: float = Field(default=0.0)  # kg
    eco_points: float = Field(default=0.0)
    
    route_type: str = Field(default="normal")
    start_location: str = Field(default="")
    end_location: str = Field(default="")
    
    date: datetime = Field(default_factory=datetime.utcnow)
```

---

### 4.6 Authentication Routes

**File:** `backend/routers/auth.py`

**Objective:** Handle user authentication, registration, and password management.

**Authentication Flow:**

```
1. REGISTER:
   - Validate email format
   - Check existing user
   - Hash password with salt
   - Create user record
   - Return success

2. LOGIN:
   - Find user by email
   - Verify password hash
   - Generate JWT token
   - Return token and user data

3. FORGOT PASSWORD:
   - Validate email exists
   - Generate reset token
   - Send email (production)
   - Return token (development)

4. PASSWORD HASHING:
   - Generate random salt (32 hex chars)
   - Concatenate: password + salt
   - Hash with SHA-256
   - Store: salt$hash
```

**JWT Token Structure:**
```
python
{
    "sub": "user_id",
    "exp": "expiration_timestamp"
}
```

---

## 5. Algorithms

### 5.1 Ant Colony Optimization (ACO)

**Algorithm Name:** ACO Route Optimizer

**Objective:** Find optimal route paths by simulating ant colony behavior.

**Core Principles:**
1. **Pheromone-based communication:** Ants leave pheromones on paths they traverse
2. **Probabilistic decision-making:** Ants choose paths based on pheromone intensity and heuristic information
3. **Iterative improvement:** Multiple iterations gradually improve solution quality
4. **Evaporation:** Pheromones evaporate to prevent premature convergence

**Pseudocode:**

```
CLASS: ACOCore
────────────────────
PROPERTIES:
  - ANT_COUNT = 20
  - MAX_ITERATIONS = 15
  - ALPHA = 1.0 (pheromone importance)
  - BETA = 2.5 (heuristic importance)
  - EVAPORATION = 0.4
  - Q = 100.0 (pheromone deposit factor)
  - WAYPOINT_COUNT = 5

METHOD: run_aco(start, end, route_type, seed)
─────────────────────────────────────────────
1. Initialize RNG with seed
2. best_fitness = infinity
3. best_ant = null

4. FOR iteration = 1 to MAX_ITERATIONS:
   a. FOR ant_id = 1 to ANT_COUNT:
       i.  ant = build_ant_path(start, end, route_type, rng)
       ii. IF ant.fitness < best_fitness:
           - best_fitness = ant.fitness
           - best_ant = ant
   
   b. Evaporate pheromones on all edges
   c. Deposit pheromones based on iteration ants

5. RETURN best_ant

METHOD: build_ant_path(start, end, route_type, rng)
──────────────────────────────────────────────────
1. Create ant with unique ID
2. Generate candidate waypoints
3. Add start waypoint to path
4. current = start waypoint

5. FOR i = 1 to WAYPOINT_COUNT:
   a. next = select_next_waypoint(candidates, current, route_type, rng, ant)
   b. IF next is null: break
   c. Add next to ant path
   d. Update cumulative distance
   e. current = next

6. Add destination to path
7. Calculate metrics (distance, time, CO2)
8. Calculate fitness

9. RETURN ant

METHOD: select_next_waypoint(candidates, current, route_type, rng, ant)
───────────────────────────────────────────────────────────────────────
1. probabilities = []

2. FOR each candidate in candidates:
   a. IF candidate.order in ant.visited: continue
   b. Get pheromone level for edge
   c. Calculate heuristic = 1 / (cost + 0.01)
   d. prob = (pheromone^ALPHA) × (heuristic^BETA)
   e. Add to probabilities

3. total_prob = sum(probabilities)

4. Roulette wheel selection:
   a. r = random(0, total_prob)
   b. cumsum = 0
   c. FOR each (candidate, prob):
       cumsum += prob
       IF cumsum >= r: RETURN candidate

5. RETURN best candidate (fallback)
```

**Heuristic Function:**
```
heuristic = 1 / (edge_cost + 0.01)

edge_cost considers:
- Distance between waypoints
- Road type (motorway vs residential)
- Traffic level
- Air quality index
- Elevation changes
```

---

### 5.2 Eco Points Calculator

**File:** `lib/algorithms/eco_points_calculator.dart`

**Objective:** Calculate sustainability scores for routes.

**Algorithm:**

```
ALGORITHM: Calculate Eco Points
───────────────────────────────
INPUT: List of routes, vehicle_type
OUTPUT: Routes with calculated ecoPoints

1. Find baseline (QUICKEST) route
2. baselineCO2 = baseline.co2Emissions

3. FOR each route:
   a. // CO2 Savings Score (40%)
      co2Savings = baselineCO2 - route.co2Emissions
      co2Score = (co2Savings / baselineCO2) × 40
      co2Score = clamp(0, 40)
   
   b. // Air Quality Score (20%)
      aqiScore = (1 - route.averageAQI / 300) × 20
      aqiScore = clamp(0, 20)
   
   c. // Traffic Efficiency Score (15%)
      trafficScore = (1 - route.trafficLevel) × 15
      trafficScore = clamp(0, 15)
   
   d. // Time Penalty (10%)
      IF route.timeVsBaseline > 20 minutes:
         timePenalty = -5
      ELSE:
         timePenalty = 0
   
   e. // Transport Mode Multiplier
      multiplier = get_transport_multiplier(vehicle_type)
   
   f. // Final Calculation
      baseScore = co2Score + aqiScore + trafficScore + timePenalty
      ecoPoints = baseScore × multiplier
      ecoPoints = clamp(5, 100)

4. RETURN routes with ecoPoints
```

**Transport Mode Multipliers:**
```
walking: 1.5
bicycle: 1.4
electric car: 1.2
hybrid car: 1.1
petrol car: 1.0
diesel car: 1.0
```

---

### 5.3 Haversine Distance Calculation

**Equation:**
```
d = 2R × arcsin(√[sin²(Δφ/2) + cos(φ₁) × cos(φ₂) × sin²(Δλ/2)])

Where:
- φ₁, φ₂ = latitudes in radians
- Δφ = latitude difference
- Δλ = longitude difference
- R = Earth's radius (6371 km)
```

**Implementation:**
```
python
def haversine_distance(p1, p2):
    lat1, lon1 = p1
    lat2, lon2 = p2
    
    R = 6371  # km
    
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    
    a = (math.sin(dlat/2)**2 + 
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * 
         math.sin(dlon/2)**2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    
    return R * c
```

---

## 6. Data Models

### 6.1 RouteData (Dart)

```
dart
class RouteData {
  final List<LatLng> points;           // Route coordinates
  final double distance;               // Distance in km
  final double duration;               // Duration in minutes
  final List<RouteInstruction> instructions;
  final double co2Emissions;           // CO2 in grams
  final double averageAQI;             // AQI value
  final double totalElevationGain;     // Elevation in meters
  final double trafficLevel;           // 0-1 scale
  final double weatherImpact;           // 0-1 scale
}
```

### 6.2 RouteOption (Dart)

```
dart
class RouteOption {
  final String type;              // "ECO CHAMPION", "BALANCED", "QUICKEST"
  final String description;
  final String icon;              // Emoji icon
  final RouteData routeData;
  final int ecoPoints;
  final int timeVsBaseline;
  final double co2Savings;
  final double averageAQI;
  final double trafficLevel;
  
  // Computed properties
  Color get cardColor;            // Green/Blue/Red based on type
  String get routeTypeDisplay;    // "Eco", "Balanced", "Normal"
}
```

### 6.3 RealTimeFactors (Dart)

```
dart
class RealTimeFactors {
  final double trafficCongestion;   // 0-1
  final double airQualityIndex;     // 0-500
  final double co2Emissions;        // g/km
  final bool hasEVCharger;
  final double weatherImpact;       // 0-1
  final double elevationGain;       // meters
  final DateTime timestamp;
}
```

---

## 7. API Integration

### 7.1 External APIs Used

**Navigation & Routing:**
- OSRM (Open Source Routing Machine)
- OpenRouteService
- TomTom API

**Weather & Environment:**
- OpenWeatherMap
- IQAir
- Open-Meteo
- OpenAQ

**Infrastructure:**
- OpenChargeMap (EV charging stations)
- Nominatim (Geocoding)
- Overpass API (OSM data)

### 7.2 Backend API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/routes/calculate` | POST | Calculate routes using ACO |
| `/api/routes/predict` | POST | Get 5-day predictions |
| `/api/predictions` | POST | Environmental predictions |
| `/auth/register` | POST | User registration |
| `/auth/login` | POST | User authentication |
| `/users/me` | GET | Get current user |
| `/trips` | GET/POST | Trip management |
| `/leaderboard` | GET | Leaderboard data |

---

## 8. Configuration

### 8.1 API Configuration

**File:** `lib/config/api_config.dart`

```
dart
class ApiConfig {
  // Backend
  static const String backendUrl = 'http://10.0.2.2:8000';
  
  // Navigation
  static const String osrmUrl = 'https://router.project-osrm.org';
  static const String tomTomApiKey = 'YOUR_TOMTOM_API_KEY';
  
  // Weather
  static const String openWeatherApiKey = 'YOUR_OPENWEATHER_API_KEY';
  
  // EV Charging
  static const String openChargeApiKey = 'YOUR_OPENCHARGE_API_KEY';
  
  // Geocoding
  static const String overpassApiUrl = 'https://overpass-api.de/api/interpreter';
}
```

### 8.2 ACO Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| ANT_COUNT | 20 | Number of ants per iteration |
| MAX_ITERATIONS | 15 | Maximum iterations |
| ALPHA | 1.0 | Pheromone importance |
| BETA | 2.5 | Heuristic importance |
| EVAPORATION | 0.4 | Pheromone decay rate |
| Q | 100.0 | Pheromone deposit factor |
| WAYPOINT_COUNT | 5 | Intermediate waypoints |

### 8.3 Eco Points Weights

| Component | Weight | Description |
|-----------|--------|-------------|
| CO2 Score | 40% | Carbon emission savings |
| AQI Score | 20% | Air quality improvement |
| Traffic Score | 15% | Traffic efficiency |
| Time Penalty | 10% | Travel time factor |
| Transport Multiplier | 15% | Mode-based bonus |

---

## 9. Security

### 9.1 Authentication

- JWT-based token authentication
- Password hashing with SHA-256 + salt
- Token expiration: 7 days

### 9.2 Privacy

- Location data used only for route calculation
- No third-party data sharing
- User data deletion supported

---

## 10. Deployment

### 10.1 Backend Setup

```
bash
# Install dependencies
cd backend
pip install -r requirements.txt

# Run server
python main.py
# Server runs on http://localhost:8000
# API docs at http://localhost:8000/docs
```

### 10.2 Frontend Setup

```
bash
# Install dependencies
flutter pub get

# Run on Android emulator
flutter run -d emulator-5554

# Run on iOS simulator
flutter run -d "iPhone 15 Pro"
```

---

## 11. Glossary

| Term | Definition |
|------|------------|
| ACO | Ant Colony Optimization - AI algorithm mimicking ant behavior |
| AQI | Air Quality Index - Measure of air pollution |
| CO2 | Carbon Dioxide - Greenhouse gas emissions |
| Eco Points | Gamification score for sustainable travel |
| OSRM | Open Source Routing Machine - Route calculation engine |
| EV | Electric Vehicle |
| JWT | JSON Web Token - Authentication standard |
| Pheromone | Chemical signal used in ACO for path selection |

---

## 12. References

- ACO Algorithm: Dorigo, M. (1992). "Optimization, Learning and Natural Algorithms"
- OSRM Documentation: https://project-osrm.org/
- OpenWeatherMap API: https://openweathermap.org/api
- FastAPI: https://fastapi.tiangolo.com/
- Flutter: https://flutter.dev/

---

*Document Version: 1.0*
*Last Updated: 2024*
*Project: Way2Sustain - Sustainable Travel Planning Application*

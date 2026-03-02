import sys
import os
from pathlib import Path
from typing import List

# Get the directory where this file is located
backend_dir = Path(__file__).parent
project_root = backend_dir.parent

# Add project root to path for imports
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Import from backend package (works when running from project root)
try:
    from backend.database import create_db_and_tables
    from backend.routers import auth, users, trips, leaderboard
    from backend.aco.aco_optimizer import ACOOptimizer, handle_aco_route_request
    from backend.aco.prediction_service import get_predictions
except ImportError:
    # Fallback for when running from backend directory
    from database import create_db_and_tables
    from routers import auth, users, trips, leaderboard
    from aco.aco_optimizer import ACOOptimizer, handle_aco_route_request
    from aco.prediction_service import get_predictions


# Helper function to calculate routes using ACO
async def calculate_routes(start, end, vehicle_type):
    """Calculate routes using ACO optimizer"""
    optimizer = ACOOptimizer()
    routes_dict = optimizer.find_all_routes(start, end, vehicle_type)
    # Convert dictionary to list for Flutter compatibility
    routes_list = list(routes_dict.values())
    return routes_list


# Helper function to calculate route cost
def calculate_route_cost(distance_km, predictions, route_type):
    """Calculate route cost based on predictions"""
    from backend.aco.environmental_cost import calculate_fitness
    
    if not predictions:
        return 0.0, {}
    
    # Get average values from predictions
    avg_traffic = sum(p.get('traffic_level', 0.5) for p in predictions) / len(predictions)
    avg_aqi = sum(p.get('aqi', 50) for p in predictions) / len(predictions)
    avg_co2 = sum(p.get('co2_emission', 50) for p in predictions) / len(predictions)
    
    # Calculate fitness
    fitness = calculate_fitness(
        total_distance=distance_km * 1000,
        total_time=(distance_km / 40) * 3600,
        total_emission=avg_co2 * distance_km / 1000,
        route_type=route_type,
        avg_traffic=avg_traffic,
        avg_aqi=avg_aqi,
    )
    
    return fitness, {
        'fitness': fitness,
        'avg_traffic': avg_traffic,
        'avg_aqi': avg_aqi,
        'avg_co2': avg_co2,
    }


# Request models
class RouteRequest(BaseModel):
    start_lat: float
    start_lng: float
    end_lat: float
    end_lng: float
    vehicle_type: str = "electric car"

class PredictRouteRequest(BaseModel):
    start_lat: float
    start_lng: float
    end_lat: float
    end_lng: float
    vehicle_type: str = "electric car"
    travel_date: str = None
    num_days: int = 5

# ==================== App Configuration ====================

app = FastAPI(
    title="Way2Sustain API",
    description="Backend API for eco-friendly trip tracking and user management",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# ==================== CORS Configuration ====================

# Allow Flutter frontend to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ==================== Startup Event ====================

@app.on_event("startup")
async def on_startup():
    """Initialize database on startup"""
    create_db_and_tables()


# ==================== Routes ====================

# Include routers with root-level paths for Flutter compatibility
app.include_router(auth.router, prefix="")
app.include_router(users.router)
app.include_router(trips.router)
app.include_router(leaderboard.router)


# ==================== Root Endpoint ====================

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Welcome to Way2Sustain API",
        "docs": "/docs",
        "version": "1.0.0"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


# ==================== Route Calculation Endpoint ====================

@app.post("/api/routes/calculate")
async def calculate_route(request: RouteRequest):
    """Calculate multiple route options using ACO + OSRM"""
    try:
        routes = await calculate_routes(
            start=(request.start_lat, request.start_lng),
            end=(request.end_lat, request.end_lng),
            vehicle_type=request.vehicle_type
        )
        return {"routes": routes, "status": "success"}
    except Exception as e:
        return {"routes": [], "status": "error", "message": str(e)}


@app.get("/api/routes/test")
async def test_routes():
    """Test endpoint for route calculation"""
    routes = await calculate_routes(
        start=(28.6139, 77.2090),
        end=(28.4595, 77.0266),
        vehicle_type="electric car"
    )
    return {"routes": routes, "status": "success"}


class PredictionRequest(BaseModel):
    start_lat: float
    start_lng: float
    end_lat: float
    end_lng: float
    vehicle_type: str = "electric car"
    num_days: int = 5


@app.post("/api/predictions")
async def get_route_predictions(request: PredictionRequest):
    """Get 5-day future predictions for traffic, AQI, weather, CO2, and EV availability."""
    try:
        predictions = await get_predictions(
            start_lat=request.start_lat,
            start_lng=request.start_lng,
            end_lat=request.end_lat,
            end_lng=request.end_lng,
            vehicle_type=request.vehicle_type,
            num_days=request.num_days,
        )
        return predictions
    except Exception as e:
        return {"status": "error", "message": str(e), "predictions": []}


@app.get("/api/predictions/test")
async def test_predictions():
    """Test endpoint for predictions"""
    try:
        result = await get_predictions(
            start_lat=8.5241,
            start_lng=76.9366,
            end_lat=9.9312,
            end_lng=76.2673,
            vehicle_type="electric car",
            num_days=5,
        )
        return result
    except Exception as e:
        return {"status": "error", "message": str(e)}


# ==================== 5-Day Prediction Endpoint ====================

@app.post("/api/routes/predict")
async def predict_route(request: PredictRouteRequest):
    """
    5-Day Future Route Prediction System
    Predicts traffic, AQI, weather, CO2 emissions, and EV charging availability
    for routes up to 5 days in advance.
    """
    try:
        # Validate num_days (max 5 days)
        num_days = min(max(1, request.num_days), 5)
        
        # Get predictions
        predictions_result = await get_predictions(
            start_lat=request.start_lat,
            start_lng=request.start_lng,
            end_lat=request.end_lat,
            end_lng=request.end_lng,
            vehicle_type=request.vehicle_type,
            num_days=num_days,
        )
        
        # Get routes with predictions integrated
        routes = await calculate_routes(
            start=(request.start_lat, request.start_lng),
            end=(request.end_lat, request.end_lng),
            vehicle_type=request.vehicle_type
        )
        
        # Calculate costs for each route using ACO fitness function
        predictions = predictions_result.get("predictions", [])
        distance_km = predictions_result.get("distance_km", 0)
        
        route_costs = {}
        for route in routes:
            route_type = route.get("route_type", "balanced")
            cost, breakdown = calculate_route_cost(
                distance_km=distance_km,
                predictions=predictions,
                route_type=route_type
            )
            route_costs[route_type] = breakdown
        
        return {
            "predictions": predictions,
            "routes": routes,
            "route_costs": route_costs,
            "distance_km": distance_km,
            "status": "success"
        }
    except Exception as e:
        return {
            "predictions": [],
            "routes": [],
            "status": "error",
            "message": str(e)
        }

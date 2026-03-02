from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from backend.database import get_session
from backend.models import User, Trip
from backend.schemas import TripCreate, TripResponse, TripWithUserStats
from backend.routers.auth import get_current_user

router = APIRouter(prefix="/trip", tags=["Trips"])


# ==================== Eco Points Calculation ====================

def calculate_eco_points(route_type: str, distance: float) -> float:
    """
    Calculate eco points based on route type and distance.
    
    Rules:
    - ECO route: 10 points per km
    - BALANCED route: 5 points per km
    - NORMAL/QUICK route: 0 points (no eco points)
    """
    route_type_lower = route_type.lower()
    
    if route_type_lower == "eco":
        return distance * 10.0
    elif route_type_lower == "balanced":
        return distance * 5.0
    else:  # normal or quick
        return 0.0


def calculate_co2_saved(distance: float) -> float:
    """
    Calculate CO2 saved based on distance.
    Average car emits ~0.21 kg CO2 per km
    Using electric vehicle saves this amount
    """
    return distance * 0.21  # kg CO2 per km


# ==================== Routes ====================

@router.post("/add", response_model=TripWithUserStats, status_code=status.HTTP_201_CREATED)
async def add_trip(
    trip_data: TripCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    """
    STEP 1-4: Complete trip flow
    
    STEP 1: POST /trip/add (this endpoint)
    STEP 2: Insert trip record
    STEP 3: Update user cumulative stats
    STEP 4: Return updated user stats in response
    """
    # Calculate eco points and CO2 saved
    eco_points = calculate_eco_points(trip_data.route_type, trip_data.distance)
    co2_saved = calculate_co2_saved(trip_data.distance)
    
    # Create trip record (STEP 2)
    new_trip = Trip(
        user_id=current_user.id,
        distance=trip_data.distance,
        duration=trip_data.duration,
        co2_saved=co2_saved,
        eco_points=eco_points,
        route_type=trip_data.route_type.lower(),
        start_location=trip_data.start_location,
        end_location=trip_data.end_location,
        date=datetime.utcnow()
    )
    
    session.add(new_trip)
    
    # Update user cumulative stats (STEP 3)
    current_user.eco_points += eco_points
    current_user.total_trips += 1
    current_user.total_km += trip_data.distance
    current_user.total_co2_saved += co2_saved
    
    session.commit()
    session.refresh(new_trip)
    session.refresh(current_user)
    
    # Return updated user stats in response (STEP 4)
    return TripWithUserStats(
        id=new_trip.id,
        user_id=new_trip.user_id,
        distance=new_trip.distance,
        duration=new_trip.duration,
        co2_saved=new_trip.co2_saved,
        eco_points=new_trip.eco_points,
        route_type=new_trip.route_type,
        start_location=new_trip.start_location,
        end_location=new_trip.end_location,
        date=new_trip.date,
        user_eco_points=current_user.eco_points,
        user_total_trips=current_user.total_trips,
        user_total_km=current_user.total_km,
        user_total_co2_saved=current_user.total_co2_saved
    )


@router.get("/{user_id}/trips", response_model=list[TripResponse])
async def get_user_trips(
    user_id: int,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    """Get all trips for a user (Trip History Page)"""
    # Verify user owns this data
    if current_user.id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access this user's trips"
        )
    
    statement = (
        select(Trip)
        .where(Trip.user_id == user_id)
        .order_by(Trip.date.desc())
    )
    trips = session.exec(statement).all()
    
    return trips


@router.get("/{trip_id}", response_model=TripResponse)
async def get_trip(
    trip_id: int,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    """Get a specific trip by ID"""
    statement = select(Trip).where(Trip.id == trip_id)
    trip = session.exec(statement).first()
    
    if not trip:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip not found"
        )
    
    # Verify user owns this trip
    if trip.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access this trip"
        )
    
    return trip

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select, func

from backend.database import get_session
from backend.models import User, Trip
from backend.schemas import UserStats, UserWithBadge, DashboardResponse, LastTripSummary
from backend.routers.auth import get_current_user

router = APIRouter(prefix="/user", tags=["Users"])


def get_user_rank(session: Session, user_id: int) -> int:
    """Get user's rank based on eco_points using DENSE_RANK"""
    # Get all users ordered by eco_points DESC
    statement = (
        select(User.id, func.rank().over(order_by=User.eco_points.desc()).label("rank"))
        .order_by(User.eco_points.desc())
    )
    results = session.exec(statement).all()
    
    for row in results:
        if row.id == user_id:
            return row.rank
    return 0


@router.get("/{user_id}/dashboard", response_model=DashboardResponse)
async def get_dashboard(
    user_id: int,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    """Get user's dashboard data for Home Page"""
    # Verify user owns this data
    if current_user.id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access this user's dashboard"
        )
    
    # Get user's rank
    rank = get_user_rank(session, user_id)
    
    # Get last trip
    statement = (
        select(Trip)
        .where(Trip.user_id == user_id)
        .order_by(Trip.date.desc())
        .limit(1)
    )
    last_trip = session.exec(statement).first()
    
    last_trip_summary = None
    if last_trip:
        last_trip_summary = LastTripSummary(
            id=last_trip.id,
            distance=last_trip.distance,
            co2_saved=last_trip.co2_saved,
            eco_points=last_trip.eco_points,
            route_type=last_trip.route_type,
            date=last_trip.date
        )
    
    return DashboardResponse(
        total_eco_points=current_user.eco_points,
        total_trips=current_user.total_trips,
        total_km=current_user.total_km,
        total_co2_saved=current_user.total_co2_saved,
        rank=rank,
        last_trip=last_trip_summary
    )


@router.get("/{user_id}/profile", response_model=UserWithBadge)
async def get_profile(
    user_id: int,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    """Get user's profile data"""
    # Verify user owns this data
    if current_user.id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access this user's profile"
        )
    
    # Get user's rank
    rank = get_user_rank(session, user_id)
    
    # Determine badge based on eco_points (future ready)
    badge = None
    if current_user.eco_points >= 10000:
        badge = "Platinum"
    elif current_user.eco_points >= 5000:
        badge = "Gold"
    elif current_user.eco_points >= 1000:
        badge = "Silver"
    elif current_user.eco_points >= 100:
        badge = "Bronze"
    
    return UserWithBadge(
        id=current_user.id,
        username=current_user.username,
        email=current_user.email,
        name=current_user.name,
        eco_points=current_user.eco_points,
        total_trips=current_user.total_trips,
        total_km=current_user.total_km,
        total_co2_saved=current_user.total_co2_saved,
        rank=rank,
        badge=badge,
        created_at=current_user.created_at
    )


@router.get("/{user_id}/stats", response_model=UserStats)
async def get_user_stats(
    user_id: int,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    """Get user's statistics"""
    # Verify user owns this data
    if current_user.id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access this user's stats"
        )
    
    rank = get_user_rank(session, user_id)
    
    return UserStats(
        id=current_user.id,
        username=current_user.username,
        email=current_user.email,
        name=current_user.name,
        eco_points=current_user.eco_points,
        total_trips=current_user.total_trips,
        total_km=current_user.total_km,
        total_co2_saved=current_user.total_co2_saved,
        rank=rank,
        created_at=current_user.created_at
    )

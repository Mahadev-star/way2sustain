from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select, func

from backend.database import get_session
from backend.models import User
from backend.schemas import LeaderboardEntry, LeaderboardResponse, UserLeaderboardPosition
from backend.routers.auth import get_current_user

router = APIRouter(prefix="/leaderboard", tags=["Leaderboard"])


@router.get("", response_model=LeaderboardResponse)
async def get_leaderboard(session: Session = Depends(get_session)):
    """
    Get full leaderboard ranked by eco_points (DENSE_RANK)
    """
    # Get all users ordered by eco_points DESC
    statement = (
        select(
            User.id,
            User.username,
            User.name,
            User.eco_points,
            User.total_trips
        )
        .order_by(User.eco_points.desc())
    )
    users = session.exec(statement).all()
    
    entries = []
    rank = 1
    for user in users:
        entries.append(LeaderboardEntry(
            rank=rank,
            user_id=user.id,
            username=user.username,
            name=user.name,
            eco_points=user.eco_points,
            total_trips=user.total_trips
        ))
        rank += 1
    
    return LeaderboardResponse(
        entries=entries,
        total_users=len(entries)
    )


@router.get("/{user_id}", response_model=UserLeaderboardPosition)
async def get_user_leaderboard_position(
    user_id: int,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    """
    Get specific user's position in leaderboard
    """
    # Verify user owns this data
    if current_user.id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access this user's leaderboard position"
        )
    
    # Get total number of users
    count_statement = select(func.count(User.id))
    total_users = session.exec(count_statement).first()
    
    # Get user's rank
    rank_statement = (
        select(func.count(User.id).label("rank"))
        .where(User.eco_points > current_user.eco_points)
    )
    users_above = session.exec(rank_statement).first()
    rank = users_above + 1 if users_above else 1
    
    return UserLeaderboardPosition(
        user_id=user_id,
        rank=rank,
        eco_points=current_user.eco_points,
        total_users=total_users
    )

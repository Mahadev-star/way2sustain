from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import Optional, List


# ==================== User Schemas ====================

class UserBase(BaseModel):
    username: str
    email: EmailStr
    name: str = ""


class UserCreate(UserBase):
    password: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(UserBase):
    """Public user response without sensitive data"""
    id: int
    eco_points: float
    total_trips: int
    total_km: float
    total_co2_saved: float
    created_at: datetime

    class Config:
        from_attributes = True


class UserStats(BaseModel):
    """User statistics for dashboard/profile"""
    id: int
    username: str
    email: str
    name: str
    eco_points: float
    total_trips: int
    total_km: float
    total_co2_saved: float
    rank: Optional[int] = None
    created_at: datetime

    class Config:
        from_attributes = True


class UserWithBadge(UserStats):
    """User stats with badge (future ready)"""
    badge: Optional[str] = None


# ==================== Trip Schemas ====================

class TripBase(BaseModel):
    distance: float = Field(..., gt=0, description="Distance in km")
    duration: float = Field(..., gt=0, description="Duration in minutes")
    route_type: str = Field(..., description="Route type: eco, balanced, normal")
    start_location: str
    end_location: str


class TripCreate(TripBase):
    """Trip creation - eco points and co2_saved calculated server-side"""
    pass


class TripResponse(BaseModel):
    """Trip response with all details"""
    id: int
    user_id: int
    distance: float
    duration: float
    co2_saved: float
    eco_points: float
    route_type: str
    start_location: str
    end_location: str
    date: datetime

    class Config:
        from_attributes = True


class TripWithUserStats(TripResponse):
    """Trip response including updated user stats"""
    user_eco_points: float
    user_total_trips: int
    user_total_km: float
    user_total_co2_saved: float


# ==================== Leaderboard Schemas ====================

class LeaderboardEntry(BaseModel):
    """Single leaderboard entry"""
    rank: int
    user_id: int
    username: str
    name: str
    eco_points: float
    total_trips: int

    class Config:
        from_attributes = True


class LeaderboardResponse(BaseModel):
    """Full leaderboard response"""
    entries: List[LeaderboardEntry]
    total_users: int


class UserLeaderboardPosition(BaseModel):
    """Specific user's position in leaderboard"""
    user_id: int
    rank: int
    eco_points: float
    total_users: int

    class Config:
        from_attributes = True


# ==================== Dashboard Schemas ====================

class LastTripSummary(BaseModel):
    """Summary of last trip"""
    id: int
    distance: float
    co2_saved: float
    eco_points: float
    route_type: str
    date: datetime

    class Config:
        from_attributes = True


class DashboardResponse(BaseModel):
    """Dashboard data for home page"""
    total_eco_points: float
    total_trips: int
    total_km: float
    total_co2_saved: float
    rank: Optional[int] = None
    last_trip: Optional[LastTripSummary] = None


# ==================== Token Schemas ====================

class Token(BaseModel):
    access_token: str
    token_type: str


class TokenData(BaseModel):
    user_id: Optional[int] = None

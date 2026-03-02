from sqlmodel import SQLModel, Field, Relationship
from datetime import datetime
from typing import Optional, List


class User(SQLModel, table=True):
    """User table with eco statistics"""
    __tablename__ = "users"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(unique=True, index=True)
    email: str = Field(unique=True, index=True)
    hashed_password: str = Field()
    name: str = Field(default="")
    
    # Eco statistics - auto-updated after each trip
    eco_points: float = Field(default=0.0)
    total_trips: int = Field(default=0)
    total_km: float = Field(default=0.0)
    total_co2_saved: float = Field(default=0.0)
    
    # Timestamps
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Relationship
    trips: List["Trip"] = Relationship(back_populates="user")


class Trip(SQLModel, table=True):
    """Trip table with route and eco data"""
    __tablename__ = "trips"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id")
    
    # Trip details
    distance: float = Field(default=0.0)  # km
    duration: float = Field(default=0.0)  # minutes
    co2_saved: float = Field(default=0.0)  # kg
    eco_points: float = Field(default=0.0)
    
    # Route type - determines eco points
    # eco: highest eco points, balanced: moderate, normal/quick: no points
    route_type: str = Field(default="normal")  # eco, balanced, normal
    
    # Locations
    start_location: str = Field(default="")
    end_location: str = Field(default="")
    
    # Timestamp
    date: datetime = Field(default_factory=datetime.utcnow)
    
    # Relationship
    user: Optional[User] = Relationship(back_populates="trips")

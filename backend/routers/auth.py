from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
import hashlib
import secrets
import logging
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import aiosmtplib
from sqlmodel import Session, select

from backend.database import get_session
from backend.models import User
from backend.schemas import UserCreate, UserResponse, Token, TokenData

# ==================== Configuration ====================
SECRET_KEY = "way2sustain-secret-key-change-in-production-2024"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 days

# ==================== Security ====================
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")

router = APIRouter(tags=["Authentication"])


# ==================== Email Configuration ====================
SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USERNAME = os.getenv("SMTP_USERNAME", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
FROM_EMAIL = os.getenv("FROM_EMAIL", "")
FROM_NAME = os.getenv("FROM_NAME", "Way2Sustain")

# ==================== Helper Functions ====================

async def send_password_reset_email(to_email: str, reset_token: str):
    """Send password reset email"""
    try:
        # Create message
        msg = MIMEMultipart()
        msg['From'] = f"{FROM_NAME} <{FROM_EMAIL}>"
        msg['To'] = to_email
        msg['Subject'] = "Password Reset - Way2Sustain"

        # Email body
        body = f"""
        Hi there,

        You requested a password reset for your Way2Sustain account.

        Your reset token is: {reset_token}

        Please use this token in the app to reset your password.

        If you didn't request this, please ignore this email.

        Best regards,
        Way2Sustain Team
        """

        msg.attach(MIMEText(body, 'plain'))

        # Connect to SMTP server
        smtp = aiosmtplib.SMTP(hostname=SMTP_SERVER, port=SMTP_PORT, use_tls=True)
        await smtp.connect()
        await smtp.login(SMTP_USERNAME, SMTP_PASSWORD)
        await smtp.send_message(msg)
        await smtp.quit()

        print(f"Password reset email sent to: {to_email}")
        return True

    except Exception as e:
        print(f"Failed to send email: {e}")
        return False


def generate_reset_token() -> str:
    """Generate a secure reset token"""
    return secrets.token_urlsafe(32)


def hash_password(password: str) -> str:
    """Hash a password using SHA-256 with salt"""
    salt = secrets.token_hex(16)
    pwd_hash = hashlib.sha256((password + salt).encode()).hexdigest()
    return f"{salt}${pwd_hash}"


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    try:
        salt, pwd_hash = hashed_password.split('$')
        return pwd_hash == hashlib.sha256((plain_password + salt).encode()).hexdigest()
    except:
        return False


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create JWT access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    session: Session = Depends(get_session)
) -> User:
    """Get current authenticated user from token"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: int = payload.get("sub")
        if user_id is None:
            raise credentials_exception
        token_data = TokenData(user_id=user_id)
    except JWTError:
        raise credentials_exception
    
    statement = select(User).where(User.id == token_data.user_id)
    user = session.exec(statement).first()
    if user is None:
        raise credentials_exception
    return user


# ==================== Routes ====================

@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(user_data: UserCreate, session: Session = Depends(get_session)):
    """Register a new user"""
    # Check if email already exists
    statement = select(User).where(User.email == user_data.email)
    existing_user = session.exec(statement).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Check if username already exists
    statement = select(User).where(User.username == user_data.username)
    existing_username = session.exec(statement).first()
    if existing_username:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already taken"
        )
    
    # Create new user with hashed password
    hashed_password = hash_password(user_data.password)
    new_user = User(
        username=user_data.username,
        email=user_data.email,
        name=user_data.name,
        hashed_password=hashed_password,
        eco_points=0.0,
        total_trips=0,
        total_km=0.0,
        total_co2_saved=0.0,
        created_at=datetime.utcnow()
    )
    
    session.add(new_user)
    session.commit()
    session.refresh(new_user)
    
    # Return in Flutter expected format
    return {
        "status": "success",
        "user": {
            "id": new_user.id,
            "username": new_user.username,
            "email": new_user.email,
            "name": new_user.name,
            "eco_points": new_user.eco_points,
            "total_trips": new_user.total_trips,
            "total_km": new_user.total_km,
            "total_co2_saved": new_user.total_co2_saved,
            "created_at": new_user.created_at.isoformat()
        }
    }


@router.post("/login")
async def login(
    request: Request,
    session: Session = Depends(get_session)
):
    """Login user and return access token - supports JSON body"""
    # Try to parse JSON body
    content_type = request.headers.get("content-type", "")
    
    if "application/json" in content_type:
        body = await request.json()
        email = body.get("username") or body.get("email")
        password = body.get("password")
    else:
        # Fall back to form data
        form_data = await request.form()
        email = form_data.get("username")
        password = form_data.get("password")
    
    if not email or not password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email and password are required"
        )
    
    # Find user by email
    statement = select(User).where(User.email == email)
    user = session.exec(statement).first()
    
    if not user or not verify_password(password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Create access token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": str(user.id)}, expires_delta=access_token_expires
    )
    
    # Return in Flutter expected format
    return {
        "status": "success",
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "email": user.email,
            "name": user.name,
            "eco_points": user.eco_points,
            "total_trips": user.total_trips,
            "total_km": user.total_km,
            "total_co2_saved": user.total_co2_saved,
            "created_at": user.created_at.isoformat()
        }
    }


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """Get current user info"""
    return current_user


@router.post("/forgot-password")
async def forgot_password(
    request: Request,
    session: Session = Depends(get_session)
):
    """
    Handle forgot password request.
    In production, this would send a password reset email.
    For now, we verify the email exists and return a success response.
    """
    try:
        body = await request.json()
        email = body.get("email")

        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email is required"
            )

        # Check if user with this email exists
        statement = select(User).where(User.email == email)
        user = session.exec(statement).first()

        if not user:
            # Don't reveal whether the email exists or not for security
            # Return success anyway to prevent email enumeration
            return {
                "status": "success",
                "message": "If an account with this email exists, a password reset link has been sent"
            }

        # Generate reset token
        reset_token = generate_reset_token()

        # In production, send email with token
        # For development, return token in response
        if SMTP_USERNAME and SMTP_PASSWORD:
            # Try to send email
            email_sent = await send_password_reset_email(user.email, reset_token)
            if email_sent:
                return {
                    "status": "success",
                    "message": "Password reset email sent successfully"
                }
            else:
                return {
                    "status": "error",
                    "message": "Failed to send email, but here's your reset token: " + reset_token
                }
        else:
            # No email config, return token directly for development
            return {
                "status": "success",
                "reset_token": reset_token,
                "message": "Reset token generated (email not configured)"
            }

    except HTTPException:
        raise
    except Exception as e:
        # Log the error for debugging
        print(f"Forgot password error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An error occurred processing your request"
        )

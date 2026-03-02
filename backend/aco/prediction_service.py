"""
Prediction Service for ACO-based Route Planning

Provides 5-day future predictions for traffic, AQI, weather, CO2 emissions, and EV availability.
"""
import random
import math
from datetime import datetime, timedelta
from typing import List, Dict, Tuple, Optional


class PredictionService:
    """Service for generating route predictions"""
    
    def __init__(self):
        self.base_traffic = 0.4
        self.base_aqi = 50.0
        self.base_weather = 0.2
        self.base_co2 = 45.0
    
    def get_predictions(
        self,
        start_lat: float,
        start_lng: float,
        end_lat: float,
        end_lng: float,
        vehicle_type: str = "electric car",
        num_days: int = 5
    ) -> Dict:
        """
        Get predictions for the next N days.
        
        Args:
            start_lat: Start latitude
            start_lng: Start longitude
            end_lat: End latitude
            end_lng: End longitude
            vehicle_type: Type of vehicle
            num_days: Number of days to predict (max 5)
        
        Returns:
            Dictionary with predictions
        """
        # Calculate base distance
        distance_km = self._calculate_distance(
            (start_lat, start_lng),
            (end_lat, end_lng)
        )
        
        predictions = []
        base_date = datetime.now()
        
        for day in range(num_days):
            date = base_date + timedelta(days=day)
            
            # Add some variation based on day of week
            day_of_week = date.weekday()
            is_weekend = day_of_week >= 5
            
            # Traffic is higher on weekdays
            traffic_multiplier = 1.2 if not is_weekend else 0.8
            
            # Generate prediction for this day
            prediction = {
                'date': date.strftime('%Y-%m-%d'),
                'day_name': date.strftime('%A'),
                'traffic_level': min(1.0, self.base_traffic * traffic_multiplier + random.uniform(-0.1, 0.1)),
                'aqi': max(20, min(200, self.base_aqi + random.uniform(-20, 30))),
                'weather_impact': max(0, min(1.0, self.base_weather + random.uniform(-0.1, 0.15))),
                'co2_emission': max(30, min(80, self.base_co2 + random.uniform(-10, 15))),
                'ev_availability': max(0.3, min(1.0, 0.7 + random.uniform(-0.2, 0.2))),
                'temperature': random.uniform(22, 32),
                'humidity': random.uniform(60, 85),
            }
            predictions.append(prediction)
        
        return {
            'predictions': predictions,
            'distance_km': distance_km,
            'vehicle_type': vehicle_type,
            'status': 'success'
        }
    
    def _calculate_distance(self, start: Tuple[float, float], end: Tuple[float, float]) -> float:
        """Calculate approximate distance in km using Haversine formula"""
        lat1, lon1 = start
        lat2, lon2 = end
        
        R = 6371  # Earth radius in km
        
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        
        a = (math.sin(dlat/2)**2 + 
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * 
             math.sin(dlon/2)**2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        
        return R * c


# Singleton instance
_prediction_service = None

def get_predictions(
    start_lat: float,
    start_lng: float,
    end_lat: float,
    end_lng: float,
    vehicle_type: str = "electric car",
    num_days: int = 5
) -> Dict:
    """Get predictions - wrapper function"""
    global _prediction_service
    if _prediction_service is None:
        _prediction_service = PredictionService()
    
    return _prediction_service.get_predictions(
        start_lat=start_lat,
        start_lng=start_lng,
        end_lat=end_lat,
        end_lng=end_lng,
        vehicle_type=vehicle_type,
        num_days=num_days
    )


def calculate_route_cost(distance_km: float, predictions: List[Dict], route_type: str) -> Tuple[float, Dict]:
    """
    Calculate route cost based on predictions.
    
    Args:
        distance_km: Route distance in km
        predictions: List of prediction dictionaries
        route_type: Type of route (eco, balanced, quickest)
    
    Returns:
        Tuple of (cost, breakdown)
    """
    if not predictions:
        return 0.0, {}
    
    # Get average values
    avg_traffic = sum(p.get('traffic_level', 0.5) for p in predictions) / len(predictions)
    avg_aqi = sum(p.get('aqi', 50) for p in predictions) / len(predictions)
    avg_co2 = sum(p.get('co2_emission', 50) for p in predictions) / len(predictions)
    
    # Calculate base cost
    base_cost = distance_km / 40  # Assume 40 km/h average
    
    # Add penalties
    traffic_penalty = avg_traffic * 0.2
    aqi_penalty = (avg_aqi / 300) * 0.15
    co2_penalty = (avg_co2 / 100) * 0.1
    
    total_cost = base_cost + traffic_penalty + aqi_penalty + co2_penalty
    
    return total_cost, {
        'base_cost': base_cost,
        'traffic_penalty': traffic_penalty,
        'aqi_penalty': aqi_penalty,
        'co2_penalty': co2_penalty,
        'total_cost': total_cost,
        'avg_traffic': avg_traffic,
        'avg_aqi': avg_aqi,
        'avg_co2': avg_co2,
    }

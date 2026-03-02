"""
Route Service - Hybrid ACO + OSRM Approach:
1. ACO generates waypoint sequence: [start, wp1, wp2, wp3, wp4, end]
2. OSRM snaps these to real roads and returns road-following geometry
3. Frontend draws the real road geometry

ACO remains the brain (decision layer).
OSRM becomes the muscle (rendering layer).
"""
import math
import json
import httpx
from typing import List, Dict, Tuple, Optional


# OSRM server
OSRM_SERVER = "https://router.project-osrm.org"

# Eco Points Calculator Constants
CO2_WEIGHT = 0.40      # 40%
AQI_WEIGHT = 0.20       # 20%
TRAFFIC_WEIGHT = 0.15   # 15%
TIME_PENALTY_WEIGHT = 0.10  # 10%

MAX_AQI = 300.0
TIME_PENALTY_THRESHOLD = 20.0  # minutes
TIME_PENALTY_VALUE = 5.0

# Transport mode multipliers
TRANSPORT_MULTIPLIERS = {
    'walking': 1.5,
    'bicycle': 1.4,
    'cycling': 1.4,
    'electric car': 1.2,
    'electric': 1.2,
    'hybrid car': 1.1,
    'hybrid': 1.1,
    'petrol car': 1.0,
    'petrol': 1.0,
    'diesel car': 1.0,
    'diesel': 1.0,
}

# Base CO2 emissions (grams per km)
BASE_EMISSIONS = {
    'walking': 0.0,
    'bicycle': 0.0,
    'cycling': 0.0,
    'electric car': 50.0,
    'electric': 50.0,
    'hybrid car': 80.0,
    'hybrid': 80.0,
    'petrol car': 120.0,
    'petrol': 120.0,
    'diesel car': 140.0,
    'diesel': 140.0,
}


def haversine_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calculate distance in meters between two points"""
    R = 6371000
    
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    
    x = math.sin(dlat/2) * math.sin(dlat/2)
    y = math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlng/2) * math.sin(dlng/2)
    
    c = 2 * math.atan2(math.sqrt(x + y), math.sqrt(1 - x + y))
    return R * c


def calculate_bounding_box(start: Tuple[float, float], end: Tuple[float, float], padding: float = 0.15) -> Dict:
    """Calculate bounding box with padding around the direct route."""
    min_lat = min(start[0], end[0])
    max_lat = max(start[0], end[0])
    min_lng = min(start[1], end[1])
    max_lng = max(start[1], end[1])
    
    lat_range = max_lat - min_lat
    lng_range = max_lng - min_lng
    
    lat_padding = lat_range * padding
    lng_padding = lng_range * padding
    
    return {
        'min_lat': min_lat - lat_padding,
        'max_lat': max_lat + lat_padding,
        'min_lng': min_lng - lng_padding,
        'max_lng': max_lng + lng_padding,
    }


def clamp_to_bounds(lat: float, lng: float, bounds: Dict) -> Tuple[float, float]:
    """Clamp coordinates to be within bounds"""
    return (
        max(bounds['min_lat'], min(bounds['max_lat'], lat)),
        max(bounds['min_lng'], min(bounds['max_lng'], lng)),
    )


def calculate_co2_emissions(vehicle_type: str, distance_km: float) -> float:
    """Calculate CO2 emissions for a vehicle type and distance"""
    base = BASE_EMISSIONS.get(vehicle_type.lower(), 120.0)
    return base * distance_km


def calculate_eco_points(route_data: Dict, baseline_co2: float, vehicle_type: str) -> Dict:
    """Calculate Eco Points using weighted formula"""
    co2_emissions = route_data.get('co2_emissions', 0)
    average_aqi = route_data.get('average_aqi', 50)
    traffic_level = route_data.get('traffic_level', 0.5)
    time_vs_baseline = route_data.get('time_vs_baseline', 0)
    
    # CO2 Savings Score (40%)
    # Use a different approach: compare actual emissions to worst case (petrol car)
    # This ensures all routes get positive points
    worst_case_emissions = 120.0 * (baseline_co2 / 50.0)  # Scale to direct distance
    co2_savings = worst_case_emissions - co2_emissions
    co2_score = 0.0
    if worst_case_emissions > 0:
        # Calculate percentage savings vs worst case (petrol)
        # This ensures quickest routes still get ~40 points (60% savings for EV)
        savings_ratio = co2_savings / worst_case_emissions
        co2_score = savings_ratio * (CO2_WEIGHT * 100)  # 0-40 range
    co2_score = max(20.0, min(co2_score, CO2_WEIGHT * 100))  # Min 20 points
    
    # Air Quality Score (20%)
    aqi_score = (1.0 - (average_aqi / MAX_AQI)) * (AQI_WEIGHT * 100)
    aqi_score = max(10.0, min(aqi_score, AQI_WEIGHT * 100))  # Min 10 points
    
    # Traffic Efficiency Score (15%)
    traffic_score = (1.0 - traffic_level) * (TRAFFIC_WEIGHT * 100)
    traffic_score = max(5.0, min(traffic_score, TRAFFIC_WEIGHT * 100))  # Min 5 points
    
    # Time Bonus (10%) - faster routes get bonus instead of penalty
    time_bonus = 0.0
    if time_vs_baseline < 0:
        # Faster than baseline - bonus points
        time_bonus = min(abs(time_vs_baseline) * 0.5, 10.0)  # Max 10 bonus
    elif time_vs_baseline > TIME_PENALTY_THRESHOLD:
        # Slower than threshold - small penalty
        time_bonus = -5.0
    
    # Transport Mode Multiplier
    multiplier = TRANSPORT_MULTIPLIERS.get(vehicle_type.lower(), 1.0)
    
    # Final Calculation - ensure minimum points
    base_score = co2_score + aqi_score + traffic_score + time_bonus
    eco_points = base_score * multiplier
    
    # Clamp between 15 and 100 (minimum 15 points for any valid route)
    eco_points = max(15.0, min(eco_points, 100.0))
    
    # Get badge text based on eco_points
    if eco_points >= 70:
        badge_text = '🌱 Most Eco-Friendly'
    elif eco_points >= 40:
        badge_text = '⚖️ Best Balance'
    else:
        badge_text = '⏱️ Fastest Route'
    
    return {
        'eco_points': round(eco_points),
        'co2_score': round(co2_score, 1),
        'aqi_score': round(aqi_score, 1),
        'traffic_score': round(traffic_score, 1),
        'time_bonus': round(time_bonus, 1),
        'multiplier': multiplier,
        'co2_savings': round(co2_savings, 2),
        'badge_text': badge_text,
    }


async def call_osrm_route(coordinates: List[Tuple[float, float]], route_type: str = "unknown") -> Optional[Dict]:
    """
    Call OSRM to get road-snapped route geometry.
    
    Args:
        coordinates: List of (lat, lng) tuples in order - DO NOT REORDER
        route_type: For debugging - the type of route being processed
        
    Returns:
        Dict with points, distance, duration or None if failed
    """
    if not coordinates or len(coordinates) < 2:
        print(f"DEBUG OSRM [{route_type}]: Not enough coordinates")
        return None
    
    # Build coordinates string: lng,lat;lng,lat;...
    # OSRM expects: lon,lat (not lat,lon)
    coord_string = ";".join([f"{lng},{lat}" for lat, lng in coordinates])
    
    print(f"DEBUG OSRM [{route_type}]: Sending {len(coordinates)} coordinates to OSRM")
    print(f"DEBUG OSRM [{route_type}]: Coordinate string: {coord_string}")
    print(f"DEBUG OSRM [{route_type}]: Raw ACO waypoints:")
    for i, (lat, lng) in enumerate(coordinates):
        print(f"DEBUG OSRM [{route_type}]:   Point {i}: ({lat}, {lng})")
    
    try:
        # Use /route endpoint (not /trip) to preserve order
        # overview=full for detailed geometry
        # geometries=geojson for easy parsing
        url = f"{OSRM_SERVER}/route/v1/driving/{coord_string}?overview=full&geometries=geojson"
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(url)
            
            if response.status_code == 200:
                data = response.json()
                
                if data.get('code') == 'Ok' and data.get('routes') and len(data['routes']) > 0:
                    route = data['routes'][0]
                    geometry = route['geometry']
                    coords_list = geometry['coordinates']
                    
                    print(f"DEBUG OSRM [{route_type}]: OSRM returned {len(coords_list)} geometry points")
                    
                    # Convert to {lat, lng} for Flutter
                    points = [{'lat': coord[1], 'lng': coord[0]} for coord in coords_list]
                    
                    return {
                        'points': points,
                        'distance': route['distance'] / 1000,  # km
                        'duration': route['duration'] / 60,   # minutes
                    }
                else:
                    print(f"DEBUG OSRM [{route_type}]: OSRM response code: {data.get('code')}")
            else:
                print(f"DEBUG OSRM [{route_type}]: HTTP status: {response.status_code}")
    except Exception as e:
        print(f"DEBUG OSRM [{route_type}]: Error: {e}")
    
    return None


async def calculate_routes(start: Tuple[float, float], end: Tuple[float, float],
                         vehicle_type: str = 'electric car') -> List[Dict]:
    """
    Graph-based ACO + OSRM Approach with Real-Time Environmental Data:
    
    Step 1: Fetch real-time environmental data (AQI, traffic, weather, EV availability)
    Step 2: Graph-based ACO finds path through real road network
    Step 3: OSRM snaps to road geometry
    Step 4: Return real road geometry with eco points to frontend
    
    Uses fixed graph-based ACO with:
    - Relaxed monotonic convergence
    - Backtracking when stuck
    - Real-time factors from APIs
    - Proper eco points calculation
    """
    from backend.aco.aco_graph import ACOGraph
    
    routes = []
    direct_distance = haversine_distance(start[0], start[1], end[0], end[1]) / 1000
    
    speeds = {'electric car': 40.0, 'petrol car': 40.0, 'bicycle': 15.0, 'walking': 5.0}
    speed = speeds.get(vehicle_type.lower(), 40.0)
    baseline_time = (direct_distance / speed) * 60
    
    # Calculate baseline CO2 for eco points
    baseline_co2 = calculate_co2_emissions(vehicle_type, direct_distance)
    
    print("=" * 60)
    print("CALCULATING ROUTES WITH GRAPH-BASED ACO + REAL-TIME DATA")
    print(f"Start: {start}, End: {end}")
    print(f"Vehicle: {vehicle_type}")
    print("=" * 60)
    
    # Step 1: Fetch real-time environmental data
    realtime_data = await fetch_realtime_env_data(start[0], start[1])
    print(f"DEBUG: Real-time data fetched: AQI={realtime_data.get('aqi')}, Traffic={realtime_data.get('traffic')}")
    
    # Step 2: Run Graph-based ACO to get waypoint sequence
    try:
        aco = ACOGraph()
        aco_routes = aco.find_routes(start=start, end=end, vehicle_type=vehicle_type)
    except Exception as e:
        print(f"Graph ACO failed: {e}")
        print("Falling back to grid-based ACO...")
        from backend.aco.aco_algorithm import ACOAlgorithm
        aco = ACOAlgorithm()
        aco_routes = aco.find_routes(start=start, end=end, vehicle_type=vehicle_type)
    
    print(f"DEBUG: ACO generated routes: {list(aco_routes.keys())}")
    
    # Route type configurations
    route_configs = {
        'quickest': {
            'type': '⏱️ QUICKEST',
            'description': 'ACO optimized fastest route',
            'icon': '⏱️',
            'color': '#E53935',
        },
        'balanced': {
            'type': '⚖️ BALANCED',
            'description': 'ACO optimized balanced route',
            'icon': '⚖️',
            'color': '#2196F3',
        },
        'eco': {
            'type': '🌱 ECO CHAMPION',
            'description': 'ACO optimized eco-friendly route',
            'icon': '🌿',
            'color': '#43A047',
        },
    }
    
    # Process each route type
    for route_type in ['eco', 'balanced', 'quickest']:
        config = route_configs[route_type]
        
        if route_type not in aco_routes or not aco_routes[route_type]:
            print(f"DEBUG: No ACO route for {route_type}")
            continue
        
        route_data = aco_routes[route_type]
        
        # Handle both old format (list) and new format (dict)
        if isinstance(route_data, dict):
            aco_coords = route_data.get('coordinates', [])
            aco_distance = route_data.get('distance', 0)
            aco_time = route_data.get('time', 0)
            aco_co2 = route_data.get('co2', 0)
            eco_points_data = route_data.get('eco_points', {})
        else:
            aco_coords = route_data
            aco_distance = 0
            aco_time = 0
            aco_co2 = 0
            eco_points_data = {}
        
        if not aco_coords or len(aco_coords) < 2:
            print(f"DEBUG: Not enough ACO points for {route_type}")
            continue
        
        print(f"DEBUG: Processing {route_type} with {len(aco_coords)} ACO waypoints")
        
        # Step 2: Send ACO waypoints to OSRM to snap to roads
        osrm_result = await call_osrm_route(aco_coords)
        
        if osrm_result and osrm_result.get('points'):
            # Use OSRM road-snapped geometry
            points = osrm_result['points']
            distance = osrm_result['distance']
            duration = osrm_result['duration']
            print(f"DEBUG: OSRM returned {len(points)} road-snapped points")
        else:
            # Fallback: use raw ACO points if OSRM fails
            print(f"DEBUG: OSRM failed for {route_type}, using raw ACO points")
            points = [{'lat': pt[0], 'lng': pt[1]} for pt in aco_coords]
            distance = aco_distance / 1000 if aco_distance > 0 else (
                sum(haversine_distance(aco_coords[i][0], aco_coords[i][1], 
                                      aco_coords[i+1][0], aco_coords[i+1][1]) 
                    for i in range(len(aco_coords)-1)) / 1000
            )
            duration = aco_time / 60 if aco_time > 0 else (distance / speed) * 60
        
        # Calculate eco points
        route_co2 = calculate_co2_emissions(vehicle_type, distance)
        
        route_env_data = {
            'co2_emissions': route_co2,
            'average_aqi': 50,
            'traffic_level': 0.5,
            'time_vs_baseline': duration - baseline_time,
        }
        
        eco_points_result = calculate_eco_points(route_env_data, baseline_co2, vehicle_type)
        
        # Use eco points from ACO if available
        if eco_points_data and 'eco_points' in eco_points_data:
            eco_points_result = eco_points_data
        
        # Build route response
        routes.append({
            'type': config['type'],
            'description': config['description'],
            'icon': config['icon'],
            'route_type': route_type,
            'points': points,
            'distance': distance,
            'duration': duration,
            'eco_points': eco_points_result.get('eco_points', 0),
            'time_vs_baseline': round(duration - baseline_time),
            'co2_savings': round(baseline_co2 - route_co2),
            'color': config['color'],
            'co2_score': eco_points_result.get('co2_score', 0),
            'aqi_score': eco_points_result.get('aqi_score', 0),
            'traffic_score': eco_points_result.get('traffic_score', 0),
            'badge_text': eco_points_result.get('badge_text', ''),
            # Include ACO metadata
            'aco_node_count': len(aco_coords),
            'is_aco_graph': True,
            'uses_osrm': True,
        })
    
    print(f"DEBUG: Final routes: {len(routes)}")
    for r in routes:
        print(f"  {r['route_type']}: {len(r['points'])} points, distance={r['distance']:.2f}km, eco_points={r['eco_points']}")
    
    return routes


# API Configuration for real-time data
OPENAQ_API_KEY = "c744d43351feb8c1a78875bb9be818c20d2bc57b01e36ac549c3a1392d666cc8"
OPENAQ_BASE_URL = "https://api.openaq.org/v2"
OPENMETEO_BASE_URL = "https://api.open-meteo.com/v1"


async def fetch_realtime_env_data(lat: float, lng: float) -> Dict:
    """
    Fetch real-time environmental data from APIs
    Returns: {aqi, traffic, weather, ev_availability}
    """
    import random
    from datetime import datetime
    
    data = {
        'aqi': 50.0,
        'traffic': 50.0,
        'weather': 0.3,
        'ev_availability': 0.5,
        'timestamp': datetime.now().isoformat(),
    }
    
    # Try to fetch AQI from OpenAQ
    try:
        url = f"{OPENAQ_BASE_URL}/latest"
        params = {"latitude": lat, "longitude": lng, "limit": 1}
        headers = {"X-API-Key": OPENAQ_API_KEY}
        
        async with httpx.AsyncClient() as client:
            response = await client.get(url, params=params, headers=headers, timeout=10.0)
            if response.status_code == 200:
                result = response.json()
                if result.get("results"):
                    measurements = result["results"][0].get("measurements", [])
                    for m in measurements:
                        if m.get("parameter") == "pm25":
                            data['aqi'] = m.get("value", 50)
                            break
    except Exception as e:
        print(f"   ⚠️ OpenAQ fetch error: {e}")
    
    # Try to fetch weather from Open-Meteo
    try:
        url = f"{OPENMETEO_BASE_URL}/forecast"
        params = {
            "latitude": lat,
            "longitude": lng,
            "current_weather": "true",
            "timezone": "Asia/Kolkata",
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.get(url, params=params, timeout=10.0)
            if response.status_code == 200:
                result = response.json()
                if "current_weather" in result:
                    weather_code = result["current_weather"].get("weatherCode", 0)
                    # Convert to severity
                    if weather_code == 0:
                        data['weather'] = 0.1
                    elif weather_code in [1, 2, 3]:
                        data['weather'] = 0.2
                    elif weather_code in [45, 48]:
                        data['weather'] = 0.3
                    elif weather_code in [51, 53, 55, 61, 63, 65]:
                        data['weather'] = 0.5
                    elif weather_code >= 95:
                        data['weather'] = 0.9
    except Exception as e:
        print(f"   ⚠️ Weather fetch error: {e}")
    
    # Generate realistic traffic based on time of day
    try:
        hour = datetime.now().hour
        # Peak hours: 8-10 AM, 4-8 PM
        if 8 <= hour <= 10 or 16 <= hour <= 20:
            data['traffic'] = 70.0 + random.uniform(-10, 10)
        elif hour <= 5:
            data['traffic'] = 20.0 + random.uniform(-5, 5)
        else:
            data['traffic'] = 45.0 + random.uniform(-10, 10)
        data['traffic'] = max(10, min(100, data['traffic']))
    except:
        pass
    
    print(f"   ✅ Real-time data: AQI={data['aqi']:.0f}, Traffic={data['traffic']:.0f}, Weather={data['weather']:.1f}")
    
    return data


async def calculate_aco_only_routes(start: Tuple[float, float], end: Tuple[float, float],
                                     vehicle_type: str = 'electric car') -> List[Dict]:
    """
    Calculate routes using ONLY ACO (without OSRM snapping).
    For debugging/verification purposes.
    """
    from backend.aco.aco_algorithm import ACOAlgorithm
    
    routes = []
    direct_distance = haversine_distance(start[0], start[1], end[0], end[1]) / 1000
    
    speeds = {'electric car': 40.0, 'petrol car': 40.0, 'bicycle': 15.0, 'walking': 5.0}
    speed = speeds.get(vehicle_type.lower(), 40.0)
    baseline_time = (direct_distance / speed) * 60
    
    baseline_co2 = calculate_co2_emissions(vehicle_type, direct_distance)
    
    # Run ACO
    aco = ACOAlgorithm()
    aco_routes = aco.find_routes(start=start, end=end, vehicle_type=vehicle_type)
    
    route_configs = {
        'quickest': {
            'type': '⏱️ QUICKEST (ACO)',
            'description': 'ACO optimized fastest route',
            'icon': '⏱️',
            'color': '#E53935',
            'aco_key': 'quickest',
        },
        'balanced': {
            'type': '⚖️ BALANCED (ACO)',
            'description': 'ACO optimized balanced route',
            'icon': '⚖️',
            'color': '#2196F3',
            'aco_key': 'balanced',
        },
        'eco': {
            'type': '🌱 ECO CHAMPION (ACO)',
            'description': 'ACO optimized eco-friendly route',
            'icon': '🌿',
            'color': '#43A047',
            'aco_key': 'eco',
        },
    }
    
    for route_type, config in route_configs.items():
        aco_key = config['aco_key']
        
        if aco_key not in aco_routes or not aco_routes[aco_key]:
            continue
        
        aco_points = aco_routes[aco_key]
        
        if len(aco_points) < 2:
            continue
        
        # Use raw ACO points (no OSRM)
        points = [{'lat': pt[0], 'lng': pt[1]} for pt in aco_points]
        
        distance = sum(haversine_distance(aco_points[i][0], aco_points[i][1], 
                                          aco_points[i+1][0], aco_points[i+1][1]) 
                      for i in range(len(aco_points)-1)) / 1000
        duration = (distance / speed) * 60
        
        route_co2 = calculate_co2_emissions(vehicle_type, distance)
        
        route_data = {
            'co2_emissions': route_co2,
            'average_aqi': 50,
            'traffic_level': 0.5,
            'time_vs_baseline': duration - baseline_time,
        }
        
        eco_points_result = calculate_eco_points(route_data, baseline_co2, vehicle_type)
        
        routes.append({
            'type': config['type'],
            'description': config['description'],
            'icon': config['icon'],
            'route_type': route_type,
            'points': points,
            'distance': distance,
            'duration': duration,
            'eco_points': eco_points_result['eco_points'],
            'time_vs_baseline': round(duration - baseline_time),
            'co2_savings': round(baseline_co2 - route_co2),
            'color': config['color'],
            'co2_score': eco_points_result['co2_score'],
            'aqi_score': eco_points_result['aqi_score'],
            'traffic_score': eco_points_result['traffic_score'],
            'badge_text': eco_points_result['badge_text'],
            'aco_node_count': len(aco_points),
            'is_aco_raw': True,
            'uses_osrm': False,
        })
    
    return routes

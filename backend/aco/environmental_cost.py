"""
Environmental Cost Module for ACO-based Route Planning

This module contains ONLY the static environmental cost logic:
- Emission calculation
- Weight definitions (eco/balanced/quickest)
- EV modifiers
- Static penalty functions
- Normalization
- Final cost computation

DO NOT include:
- HTTP calls
- API clients
- Real-time fetch logic
"""
import math
import numpy as np
from typing import Dict, Tuple, Optional
from dataclasses import dataclass


# =============================================================================
# ROUTE WEIGHT DEFINITIONS
# =============================================================================

@dataclass
class RouteWeights:
    """Weight definitions for different route types"""
    emission_weight: float
    distance_weight: float
    time_weight: float


# Route type weight configurations
ROUTE_WEIGHTS = {
    'eco': RouteWeights(
        emission_weight=0.6,
        distance_weight=0.3,
        time_weight=0.1,
    ),
    'balanced': RouteWeights(
        emission_weight=0.33,
        distance_weight=0.33,
        time_weight=0.34,
    ),
    'quickest': RouteWeights(
        emission_weight=0.1,
        distance_weight=0.2,
        time_weight=0.7,
    ),
}


# =============================================================================
# VEHICLE EMISSION FACTORS
# =============================================================================

# Base CO2 emissions (grams per km) by vehicle type
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

# EV multipliers for eco-bonus
EV_MULTIPLIERS = {
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


# =============================================================================
# SPEED-BASED EMISSION FACTORS
# =============================================================================

def get_speed_emission_factor(speed_kph: float) -> float:
    """
    Speed-based emission factor in kg CO2 per km.
    
    Args:
        speed_kph: Speed in kilometers per hour
        
    Returns:
        Emission factor in kg CO2 per km
    """
    if speed_kph < 30:
        return 0.22  # city traffic - inefficient
    elif speed_kph < 50:
        return 0.18  # normal - most efficient
    elif speed_kph < 70:
        return 0.20  # highway
    else:
        return 0.25  # fast - less efficient


def get_speed_category(speed_kph: float) -> str:
    """Get speed category string for debugging."""
    if speed_kph < 30:
        return "city_traffic"
    elif speed_kph < 50:
        return "normal"
    elif speed_kph < 70:
        return "highway"
    else:
        return "fast"


# =============================================================================
# EMISSION CALCULATION
# =============================================================================

def calculate_co2_emissions(vehicle_type: str, distance_km: float) -> float:
    """
    Calculate CO2 emissions for a vehicle type and distance.
    
    Args:
        vehicle_type: Type of vehicle (e.g., 'electric car', 'petrol car')
        distance_km: Distance in kilometers
        
    Returns:
        CO2 emissions in grams
    """
    base = BASE_EMISSIONS.get(vehicle_type.lower(), 120.0)
    return base * distance_km


def calculate_edge_emission(length_m: float, speed_kph: float) -> float:
    """
    Calculate emission for an edge based on length and speed.
    
    Args:
        length_m: Edge length in meters
        speed_kph: Speed in km/h
        
    Returns:
        Emission in kg CO2
    """
    length_km = length_m / 1000
    emission_factor = get_speed_emission_factor(speed_kph)
    return length_km * emission_factor


# =============================================================================
# STATIC PENALTY FUNCTIONS
# =============================================================================

# AQI penalty weights
AQI_WEIGHT = 0.20
MAX_AQI = 300.0

# Traffic penalty weights  
TRAFFIC_WEIGHT = 0.15

# Time penalty weights
TIME_PENALTY_WEIGHT = 0.10
TIME_PENALTY_THRESHOLD = 20.0  # minutes
TIME_PENALTY_VALUE = 5.0

# CO2 weight for eco points calculation
CO2_WEIGHT = 0.40


def calculate_aqi_penalty(aqi: float) -> float:
    """Calculate AQI penalty (0-1 range)."""
    return min(1.0, aqi / MAX_AQI)


def calculate_traffic_penalty(traffic_level: float) -> float:
    """Calculate traffic penalty (0-1 range)."""
    return min(1.0, traffic_level)


def calculate_time_penalty(time_vs_baseline: float) -> float:
    """Calculate time penalty based on deviation from baseline."""
    if time_vs_baseline > TIME_PENALTY_THRESHOLD:
        return -TIME_PENALTY_VALUE
    return 0.0


def calculate_weather_penalty(weather_impact: float) -> float:
    """Calculate weather impact penalty (0-1 range)."""
    return min(1.0, weather_impact)


def calculate_elevation_penalty(elevation_gain: float, max_elevation: float = 500.0) -> float:
    """Calculate elevation penalty based on elevation gain."""
    return min(1.0, elevation_gain / max_elevation)


# =============================================================================
# ROAD TYPE PENALTIES
# =============================================================================

def get_road_type_multiplier(highway: str) -> float:
    """
    Get penalty/bonus multiplier based on road type.
    
    Args:
        highway: OSM highway tag value
        
    Returns:
        Multiplier (lower = more eco-friendly)
    """
    highway_str = str(highway).lower()
    
    if 'motorway' in highway_str:
        return 3.0
    elif 'primary' in highway_str:
        return 2.5
    elif 'secondary' in highway_str:
        return 2.0
    elif 'tertiary' in highway_str:
        return 1.5
    elif 'residential' in highway_str or 'service' in highway_str:
        return 0.5
    elif 'footway' in highway_str or 'path' in highway_str:
        return 0.2
    else:
        return 1.0  # default road


# =============================================================================
# NORMALIZATION
# =============================================================================

def compute_percentile_normalization(values: list, p5: float = None, p95: float = None) -> Tuple[float, float, float, float]:
    """Compute 5th and 95th percentile normalization bounds."""
    if p5 is None:
        p5 = np.percentile(values, 5)
    if p95 is None:
        p95 = np.percentile(values, 95)
    
    eps = 0.0001
    normalized = [(v - p5) / (p95 - p5 + eps) for v in values]
    normalized = [max(0, min(1, n)) for n in normalized]
    
    mean_norm = np.mean(normalized) if normalized else 0.5
    std_norm = np.std(normalized) if normalized else 0.25
    
    return p5, p95, mean_norm, std_norm


def normalize_value(value: float, p5: float, p95: float) -> float:
    """Normalize a value using percentile bounds."""
    eps = 0.0001
    normalized = (value - p5) / (p95 - p5 + eps)
    return max(0.0, min(1.0, normalized))


# =============================================================================
# EDGE COST COMPUTATION - FIXED VERSION
# =============================================================================

def compute_edge_cost(
    edge_data: Dict,
    route_type: str,
    global_stats: Dict = None,
    epsilon: float = 0.0001,
) -> float:
    """
    Compute edge cost based on route type with PROPER SCALING.
    
    Uses RAW values (not min-max normalized) to ensure meaningful differentiation
    between eco/balanced/quickest routes.
    
    Args:
        edge_data: Dictionary containing edge attributes
        route_type: Type of route ('eco', 'balanced', 'quickest')
        global_stats: Optional global statistics (not used for normalization)
        epsilon: Small value to avoid division by zero
        
    Returns:
        Computed edge cost (lower = better for that route type)
    """
    # Extract edge attributes
    length = edge_data.get('length', 100.0)
    travel_time = edge_data.get('travel_time', 10.0)
    speed_kph = edge_data.get('speed_kph', 40.0)
    highway = edge_data.get('highway', 'road')
    
    # Calculate emission in kg
    emission_kg = calculate_edge_emission(length, speed_kph)
    
    # Get route weights
    weights = ROUTE_WEIGHTS.get(route_type, ROUTE_WEIGHTS['balanced'])
    
    # Get road type multiplier (penalizes faster roads for eco routes)
    road_multiplier = get_road_type_multiplier(highway)
    
    # Compute cost using RAW scaled values (not normalized!)
    # This ensures different route types have different cost profiles
    cost = (
        weights.emission_weight * emission_kg * 100 +
        weights.distance_weight * length * 0.01 +
        weights.time_weight * travel_time * 0.1
    ) * road_multiplier
    
    # Apply route-type specific scaling to further differentiate
    if route_type == 'eco':
        cost *= 1.5  # Amplify eco differences
    elif route_type == 'quickest':
        cost *= 0.8  # Reduce quickest costs
    
    # Clamp to reasonable range [0.1, 10.0]
    cost = max(0.1, min(10.0, cost))
    cost += epsilon
    
    return cost


def compute_edge_costs_all_routes(edge_data: Dict, global_stats: Dict = None) -> Dict[str, float]:
    """Compute costs for all route types for an edge."""
    return {
        'eco': compute_edge_cost(edge_data, 'eco', global_stats),
        'balanced': compute_edge_cost(edge_data, 'balanced', global_stats),
        'quickest': compute_edge_cost(edge_data, 'quickest', global_stats),
    }


# =============================================================================
# FITNESS CALCULATION
# =============================================================================

def calculate_fitness(
    total_distance: float,
    total_time: float,
    total_emission: float,
    route_type: str,
    avg_traffic: float = 0.4,
    avg_aqi: float = 50.0,
) -> float:
    """Calculate fitness for an ant/path based on route type."""
    if total_distance <= 0:
        return float('inf')
    
    # Normalize values
    norm_distance = total_distance / 50000  # 50km max
    norm_time = total_time / 3600  # 1 hour max
    norm_emission = total_emission / 5.0  # 5kg max
    
    # Get route weights
    weights = ROUTE_WEIGHTS.get(route_type, ROUTE_WEIGHTS['balanced'])
    
    # Calculate base fitness
    fitness = (
        weights.distance_weight * norm_distance +
        weights.time_weight * norm_time +
        weights.emission_weight * norm_emission
    )
    
    # Add traffic penalty
    fitness += avg_traffic * TRAFFIC_WEIGHT
    
    # Add AQI penalty (normalized)
    fitness += (avg_aqi / MAX_AQI) * AQI_WEIGHT
    
    return fitness if math.isfinite(fitness) else float('inf')


# =============================================================================
# ECO POINTS CALCULATION
# =============================================================================

def calculate_eco_points(
    co2_emissions: float,
    baseline_co2: float,
    average_aqi: float,
    traffic_level: float,
    time_vs_baseline: float,
    vehicle_type: str,
) -> Dict:
    """Calculate eco points for a route."""
    # CO2 Savings Score (40%)
    # Use worst case (petrol car) as baseline to ensure all routes get positive points
    worst_case_emissions = 120.0 * (baseline_co2 / 50.0) if baseline_co2 > 0 else 120.0
    co2_savings = worst_case_emissions - co2_emissions
    co2_score = 0.0
    if worst_case_emissions > 0:
        # Calculate percentage savings vs worst case (petrol)
        savings_ratio = co2_savings / worst_case_emissions
        co2_score = savings_ratio * (CO2_WEIGHT * 100)
    co2_score = max(20.0, min(co2_score, CO2_WEIGHT * 100))
    
    # Air Quality Score (20%)
    aqi_score = (1.0 - (average_aqi / MAX_AQI)) * (AQI_WEIGHT * 100)
    aqi_score = max(10.0, min(aqi_score, AQI_WEIGHT * 100))
    
    # Traffic Efficiency Score (15%)
    traffic_score = (1.0 - traffic_level) * (TRAFFIC_WEIGHT * 100)
    traffic_score = max(5.0, min(traffic_score, TRAFFIC_WEIGHT * 100))
    
    # Time Bonus (10%) - faster routes get bonus instead of penalty
    time_bonus = 0.0
    if time_vs_baseline < 0:
        time_bonus = min(abs(time_vs_baseline) * 0.5, 10.0)
    elif time_vs_baseline > TIME_PENALTY_THRESHOLD:
        time_bonus = -5.0
    
    # Transport Mode Multiplier
    multiplier = EV_MULTIPLIERS.get(vehicle_type.lower(), 1.0)
    
    # Final Calculation
    base_score = co2_score + aqi_score + traffic_score + time_bonus
    eco_points = base_score * multiplier
    
    # Clamp between 15 and 100
    eco_points = max(15.0, min(eco_points, 100.0))
    
    # Get badge text
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


# =============================================================================
# GLOBAL STATS COMPUTATION
# =============================================================================

def compute_global_edge_stats(G) -> Dict:
    """Compute global min/max/mean for edge attributes across entire graph."""
    distances = []
    times = []
    emissions = []
    
    for u, v, data in G.edges(data=True):
        dist = data.get('length', 100.0)
        time = data.get('travel_time', 10.0)
        speed_kph = data.get('speed_kph', 40.0)
        emission = calculate_edge_emission(dist, speed_kph)
        
        distances.append(dist)
        times.append(time)
        emissions.append(emission)
    
    return {
        'distance': {
            'min': min(distances),
            'max': max(distances),
            'mean': sum(distances) / len(distances) if distances else 100.0
        },
        'time': {
            'min': min(times),
            'max': max(times),
            'mean': sum(times) / len(times) if times else 10.0
        },
        'emission': {
            'min': min(emissions),
            'max': max(emissions),
            'mean': sum(emissions) / len(emissions) if emissions else 0.2
        }
    }


# =============================================================================
# PRECOMPUTE EDGE COSTS FOR GRAPH
# =============================================================================

def precompute_edge_costs(G, global_stats: Dict = None) -> Dict[Tuple, Dict[str, float]]:
    """Precompute edge costs for all route types."""
    if global_stats is None:
        global_stats = compute_global_edge_stats(G)
    
    edge_costs = {}
    
    for u, v, data in G.edges(data=True):
        costs = compute_edge_costs_all_routes(data, global_stats)
        
        # Store both directions
        edge_costs[(u, v)] = costs
        edge_costs[(v, u)] = costs
    
    return edge_costs


# =============================================================================
# EXPORTED FUNCTIONS
# =============================================================================

__all__ = [
    # Route weights
    'RouteWeights',
    'ROUTE_WEIGHTS',
    
    # Vehicle factors
    'BASE_EMISSIONS',
    'EV_MULTIPLIERS',
    
    # Emission calculation
    'get_speed_emission_factor',
    'get_speed_category',
    'calculate_co2_emissions',
    'calculate_edge_emission',
    
    # Penalty functions
    'calculate_aqi_penalty',
    'calculate_traffic_penalty',
    'calculate_time_penalty',
    'calculate_weather_penalty',
    'calculate_elevation_penalty',
    'get_road_type_multiplier',
    
    # Normalization
    'compute_percentile_normalization',
    'normalize_value',
    
    # Cost computation
    'compute_edge_cost',
    'compute_edge_costs_all_routes',
    
    # Fitness
    'calculate_fitness',
    
    # Eco points
    'calculate_eco_points',
    
    # Global stats
    'compute_global_edge_stats',
    'precompute_edge_costs',
]

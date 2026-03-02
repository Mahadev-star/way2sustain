"""
ACO (Ant Colony Optimization) Module for Way2Sustain

This module provides ACO-based route optimization with:
- ACO core algorithm for waypoint generation
- Real-time environmental factors integration
- OSRM route drawing integration
- Eco points calculation
- Prediction service for 5-day forecasts
"""

from backend.aco.aco_optimizer import (
    ACOOptimizer,
    ACOCore,
    OSRMConnector,
    RealTimeFactors,
    Ant,
    Waypoint,
    handle_aco_route_request,
)

from backend.aco.environmental_cost import (
    ROUTE_WEIGHTS,
    BASE_EMISSIONS,
    EV_MULTIPLIERS,
    calculate_co2_emissions,
    calculate_edge_emission,
    calculate_eco_points,
    calculate_fitness,
)

from backend.aco.prediction_service import (
    PredictionService,
    get_predictions,
    calculate_route_cost,
)

__all__ = [
    # Optimizer classes
    'ACOOptimizer',
    'ACOCore',
    'OSRMConnector',
    'RealTimeFactors',
    'Ant',
    'Waypoint',
    'handle_aco_route_request',
    
    # Environmental costs
    'ROUTE_WEIGHTS',
    'BASE_EMISSIONS',
    'EV_MULTIPLIERS',
    'calculate_co2_emissions',
    'calculate_edge_emission',
    'calculate_eco_points',
    'calculate_fitness',
    
    # Prediction service
    'PredictionService',
    'get_predictions',
    'calculate_route_cost',
]

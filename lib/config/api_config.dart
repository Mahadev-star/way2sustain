// lib/config/api_config.dart
class ApiConfig {
  // ==================== BACKEND API ====================

  // Python FastAPI backend URL
  static const String backendUrl = 'http://10.0.2.2:8000'; // Android emulator
  // static const String backendUrl = 'http://localhost:8000';  // iOS simulator
  // static const String backendUrl = 'http://192.168.1.x:8000';  // Physical device

  static const String routeCalculateEndpoint = '/api/routes/calculate';
  static const String routeTestEndpoint = '/api/routes/test';
  static const String predictRouteEndpoint = '/api/routes/predict';

  // ==================== NAVIGATION & ROUTING APIS ====================

  // TomTom API - Navigation, traffic, and search services
  static const String tomTomApiKey = 'YOUR_TOMTOM_API_KEY';
  static const String tomTomBaseUrl = 'https://api.tomtom.com';
  static const String tomTomTrafficUrl =
      'https://api.tomtom.com/traffic/services/4/flowSegmentData/relative/10/json';
  static const String tomTomSearchUrl = 'https://api.tomtom.com/search/2';

  // MyTomTom API - Future prediction traffic data
  static const String myTomTomApiKey = 'YOUR_MYTOMTOM_API_KEY';
  static const String myTomTomBaseUrl = 'https://api.tomtom.com';

  // OpenRouteService API - Routing and directions
  static const String openRouteServiceApiKey = 'YOUR_OPENROUTESERVICE_API_KEY';
  static const String openRouteServiceUrl =
      'https://api.openrouteservice.org/v2';

  // Additional OpenRouteService key
  static const String openRouteServiceApiKey2 =
      'YOUR_OPENROUTESERVICE_API_KEY_2';

  // OSRM API - Open Source Routing Machine (no key required)
  static const String osrmUrl = 'https://router.project-osrm.org';

  // SimpleRouting.io API - Alternative routing service
  static const String simpleRoutingApiKey = 'YOUR_SIMPLE_ROUTING_API_KEY';
  static const String simpleRoutingUrl = 'https://api.simplerouting.io';

  // ==================== WEATHER & ENVIRONMENTAL APIS ====================

  // OpenWeather API - Weather data and air pollution
  // Multiple API keys for redundancy/rate limiting
  static const String openWeatherApiKey = 'YOUR_OPENWEATHER_API_KEY';
  static const String openWeatherApiKey2 = 'YOUR_OPENWEATHER_API_KEY_2';
  static const String openWeatherApiKey3 = 'YOUR_OPENWEATHER_API_KEY_3';
  static const String openWeatherApiKey4 = 'YOUR_OPENWEATHER_API_KEY_4';
  static const String openWeatherApiKey5 = 'YOUR_OPENWEATHER_API_KEY_5';

  static const String openWeatherBaseUrl =
      'https://api.openweathermap.org/data/2.5';
  static const String openWeatherAirUrl =
      'https://api.openweathermap.org/data/2.5/air_pollution';
  static const String openWeatherWeatherUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  // IQAir API - Air quality data
  static const String iqAirApiKey = 'YOUR_IQAIR_API_KEY';
  static const String iqAirUrl = 'https://api.airvisual.com/v2';

  // Open-Meteo API - Free weather forecasts (no key required)
  static const String openMeteoUrl = 'https://api.open-meteo.com/v1';

  // OpenAQ API - Open air quality data
  static const String openaqApiKey = 'YOUR_OPENAQ_API_KEY';
  static const String openaqUrl = 'https://api.openaq.org/v2';
  static const String openaqHistoricalUrl = 'https://api.openaq.org/v3';

  // Calendarific API - Holiday calendar data
  static const String calendarificApiKey = 'YOUR_CALENDARIFIC_API_KEY';
  static const String calendarificUrl = 'https://calendarific.com/api/v3';

  // ==================== ELEVATION & TERRAIN APIS ====================

  // Open-Elevation API - Elevation data
  static const String openElevationUrl =
      'https://api.open-elevation.com/api/v1/lookup';

  // OpenTopoData API - Topographic data
  static const String openTopoDataUrl = 'https://api.opentopodata.org/v1';

  // ==================== POI & INFRASTRUCTURE APIS ====================

  // OpenCharge API - Electric vehicle charging stations
  static const String openChargeApiKey = 'YOUR_OPENCHARGE_API_KEY';
  static const String openChargeApiKey2 = 'YOUR_OPENCHARGE_API_KEY_2';
  static const String openChargeApiKey3 = 'YOUR_OPENCHARGE_API_KEY_3';
  static const String openChargeApiKey4 = 'YOUR_OPENCHARGE_API_KEY_4';

  static const String openChargeUrl = 'https://api.openchargemap.io/v3/poi';

  // Overpass API - OpenStreetMap data querying
  static const String overpassApiUrl =
      'https://overpass-api.de/api/interpreter';
}

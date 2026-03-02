import 'package:flutter/material.dart';
import 'route_data.dart';

class RouteOption {
  final String type;
  final String description;
  final String icon;
  final RouteData routeData;
  final int ecoPoints;
  final int timeVsBaseline;
  final double co2Savings;
  final double averageAQI;
  final double trafficLevel;

  RouteOption({
    required this.type,
    required this.description,
    required this.icon,
    required this.routeData,
    required this.ecoPoints,
    required this.timeVsBaseline,
    required this.co2Savings,
    required this.averageAQI,
    required this.trafficLevel,
  });

  // Computed properties used in the UI
  // Color mapping:
  // - Green Shade → Eco Route (ECO CHAMPION)
  // - Blue Shade → Balanced Route (BALANCED)
  // - Red Shade → Normal (Quick) Route (QUICKEST)
  Color get cardColor {
    // Handle both with and without emoji prefixes
    if (type.contains('ECO CHAMPION') || type.contains('ECO')) {
      return const Color(0xFF43A047); // Green shade
    } else if (type.contains('BALANCED')) {
      return const Color(0xFF2196F3); // Blue shade
    } else if (type.contains('QUICKEST') || type.contains('Fast')) {
      return const Color(0xFFE53935); // Red shade
    }
    return Colors.grey;
  }

  // Darker shade for selected state
  Color get selectedColor {
    if (type.contains('ECO CHAMPION') || type.contains('ECO')) {
      return const Color(0xFF2E7D32); // Darker green
    } else if (type.contains('BALANCED')) {
      return const Color(0xFF1565C0); // Darker blue
    } else if (type.contains('QUICKEST') || type.contains('Fast')) {
      return const Color(0xFFC62828); // Darker red
    }
    return Colors.grey.shade700;
  }

  // Get route type display name
  String get routeTypeDisplay {
    if (type.contains('ECO CHAMPION') || type.contains('ECO')) {
      return 'Eco';
    } else if (type.contains('BALANCED')) {
      return 'Balanced';
    } else if (type.contains('QUICKEST') || type.contains('Fast')) {
      return 'Normal';
    }
    return type;
  }

  String get badgeText {
    if (type.contains('ECO CHAMPION') || type.contains('ECO')) {
      return '🌱 Most Eco-Friendly';
    } else if (type.contains('BALANCED')) {
      return '⚖️ Best Balance';
    } else if (type.contains('QUICKEST') || type.contains('Fast')) {
      return '⏱️ Fastest Route';
    }
    return type;
  }
}

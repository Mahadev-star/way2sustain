import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapSelectionScreen extends StatefulWidget {
  final bool isFromField;
  final LatLng? initialLocation;

  const MapSelectionScreen({
    super.key,
    required this.isFromField,
    this.initialLocation,
  });

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  String? _selectedAddress;

  // Search for location using Nominatim API
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=5',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'SustainableTravelApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data
              .map(
                (item) => {
                  'display_name': item['display_name'],
                  'lat': double.parse(item['lat']),
                  'lon': double.parse(item['lon']),
                  'type': item['type'],
                },
              )
              .toList();
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Search error: $e');
      }
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  // Select a search result
  void _selectSearchResult(Map<String, dynamic> result) {
    final latLng = LatLng(result['lat'], result['lon']);

    setState(() {
      _selectedLocation = latLng;
      _selectedAddress = result['display_name'];
      _searchResults = [];
      _searchController.text = result['display_name'];
    });

    // Move map to selected location
    _mapController.move(latLng, 15.0);

    // Close keyboard
    FocusScope.of(context).unfocus();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _mapController.move(widget.initialLocation!, 13.0);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isFromField ? "Select From Location" : "Select To Location",
        ),
        actions: [
          if (_selectedLocation != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () => Navigator.pop(context, _selectedLocation),
              tooltip: "Confirm selection",
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search for a place...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchResults = [];
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (query) {
                    if (query.length > 2) {
                      _searchLocation(query);
                    } else {
                      setState(() {
                        _searchResults = [];
                      });
                    }
                  },
                  onSubmitted: (query) {
                    if (query.isNotEmpty) {
                      _searchLocation(query);
                    }
                  },
                ),

                // Search Results
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          // ignore: deprecated_member_use
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: Icon(
                            _getLocationIcon(result['type']),
                            color: Colors.blue,
                          ),
                          title: Text(
                            result['display_name'],
                            style: const TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),

                // Loading indicator
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Searching...'),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        widget.initialLocation ??
                        const LatLng(10.7867, 76.6548), // Default: Palakkad
                    initialZoom: 13.0,
                    onTap: (tapPosition, latLng) {
                      setState(() {
                        _selectedLocation = latLng;
                        _selectedAddress =
                            null; // Clear address when tapping directly on map
                        _searchController.clear();
                        _searchResults = [];
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'com.example.sustainable_travel_app',
                    ),
                    MarkerLayer(
                      markers: [
                        if (_selectedLocation != null)
                          Marker(
                            point: _selectedLocation!,
                            width: 60,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    // ignore: deprecated_member_use
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                widget.isFromField
                                    ? Icons.location_searching
                                    : Icons.location_on,
                                color: widget.isFromField
                                    ? Colors.green
                                    : Colors.red,
                                size: 40,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Current location button
                Positioned(
                  bottom: 100,
                  right: 16,
                  child: FloatingActionButton.small(
                    onPressed: () {
                      if (_selectedLocation != null) {
                        _mapController.move(_selectedLocation!, 15.0);
                      }
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: Colors.blue),
                  ),
                ),

                // Zoom controls
                Positioned(
                  bottom: 50,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(
                            _mapController.camera.center,
                            currentZoom + 1,
                          );
                        },
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.add, color: Colors.blue),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(
                            _mapController.camera.center,
                            currentZoom - 1,
                          );
                        },
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.remove, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Selection Info
          if (_selectedLocation != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isFromField
                                  ? "From Location"
                                  : "To Location",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            if (_selectedAddress != null)
                              Text(
                                _selectedAddress!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, _selectedLocation),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          "SELECT",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  // Reverse geocoding button
                  if (_selectedAddress == null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          // Get address from coordinates (reverse geocoding)
                          try {
                            final url = Uri.parse(
                              'https://nominatim.openstreetmap.org/reverse?'
                              'format=json&'
                              'lat=${_selectedLocation!.latitude}&'
                              'lon=${_selectedLocation!.longitude}',
                            );

                            final response = await http.get(
                              url,
                              headers: {
                                'User-Agent': 'SustainableTravelApp/1.0',
                              },
                            );

                            if (response.statusCode == 200) {
                              final data = json.decode(response.body);
                              setState(() {
                                _selectedAddress = data['display_name'];
                              });
                            }
                          } catch (e) {
                            if (kDebugMode) {
                              print('Reverse geocoding error: $e');
                            }
                          }
                        },
                        icon: const Icon(Icons.location_searching, size: 16),
                        label: const Text(
                          "Get Address",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Helper to get appropriate icon based on location type
  IconData _getLocationIcon(String? type) {
    switch (type) {
      case 'city':
      case 'town':
        return Icons.location_city;
      case 'village':
        return Icons.house;
      case 'administrative':
        return Icons.account_balance;
      case 'railway':
        return Icons.train;
      case 'road':
        return Icons.directions;
      case 'water':
        return Icons.water;
      default:
        return Icons.place;
    }
  }
}

"""
Fast Kerala Graph Download using OSMnx
This will directly download Kerala road network without processing the entire India PBF.
"""
import osmnx as ox
import networkx as nx
import os

# Configuration
OUTPUT_FILE = "backend/southern_zone_graph.gpickle"

# Kerala coordinates - using polygon for more accurate boundary
# Kerala state boundary approximate coordinates
KERALA_POLYGON = """
8.8819,76.5849 8.9249,76.4725 9.2399,76.5289 9.5899,76.1377 9.8491,76.8859 
9.9228,76.6317 10.2948,76.7871 10.4433,76.4941 10.8077,76.9125 10.9544,76.6927 
11.4591,76.7919 11.7877,76.6413 12.2363,75.3954 12.0639,74.6228 11.7824,74.2349 
11.5765,74.3617 11.1876,74.7512 10.9753,75.1592 10.8174,75.4009 10.2948,75.7557 
9.9228,76.1661 9.5483,76.4623 9.2399,76.5289 8.8819,76.5849
"""

# Alternative: Use bounding box for Kerala
# North: 12.5, South: 8.0, East: 77.5, West: 76.0
KERALA_BBOX = (12.5, 8.0, 77.5, 76.0)

HIGHWAY_SPEED_LIMITS = {
    'motorway': 100, 'motorway_link': 60,
    'trunk': 80, 'trunk_link': 50,
    'primary': 65, 'primary_link': 45,
    'secondary': 55, 'secondary_link': 40,
    'tertiary': 45, 'tertiary_link': 35,
    'residential': 30, 'unclassified': 40,
    'living_street': 20, 'service': 25, 'road': 40,
}

def get_speed_kph(highway):
    for hw, speed in HIGHWAY_SPEED_LIMITS.items():
        if hw in str(highway):
            return float(speed)
    return 40.0


print("=" * 60)
print("FAST KERALA GRAPH DOWNLOAD USING OSMNX")
print("=" * 60)

# Download with simplify=False to preserve attributes
print("\n[1/4] Downloading OSM data for Kerala...")
print("      Using bounding box method (faster)")

try:
    G = ox.graph_from_bbox(
        bbox=KERALA_BBOX,
        network_type="drive",
        simplify=False  # IMPORTANT: Keep all attributes
    )
    print(f"    Downloaded: {len(G.nodes())} nodes, {len(G.edges())} edges")
except Exception as e:
    print(f"    Error with bbox: {e}")
    print("    Trying with place name...")
    G = ox.graph_from_place("Kerala, India", network_type="drive", simplify=False)
    print(f"    Downloaded: {len(G.nodes())} nodes, {len(G.edges())} edges")

# Add speed and travel time
print("\n[2/4] Computing speeds and travel times...")
for u, v, data in G.edges(data=True):
    highway = data.get('highway', 'road')
    speed = get_speed_kph(highway)
    data['speed_kph'] = speed
    
    length = data.get('length', 100.0)
    data['travel_time'] = (length / 1000) / (speed / 3.6) if speed > 0 else length / 10
    
    # Add emission
    data['emission_kg'] = (length / 1000) * 0.2

# Sample edges
print("\n[3/4] Sample edge attributes...")
sample = list(G.edges(data=True))[:10]
print("\n" + "=" * 70)
for i, (u, v, d) in enumerate(sample):
    print(f"Edge {i+1}: {u}->{v}")
    print(f"  highway: {d.get('highway')}")
    print(f"  length: {d.get('length', 0):.1f}m, speed: {d.get('speed_kph', 0):.0f}km/h")
print("=" * 70)

# Check highway types
highways = {}
for u, v, d in G.edges(data=True):
    hw = d.get('highway', 'unknown')
    highways[hw] = highways.get(hw, 0) + 1
print(f"\nHighway types: {dict(sorted(highways.items(), key=lambda x: -x[1])[:8])}")

# Save
print("\n[4/4] Saving graph...")

# Backup old graph
if os.path.exists(OUTPUT_FILE):
    backup_file = OUTPUT_FILE.replace('.gpickle', '_backup.gpickle')
    os.rename(OUTPUT_FILE, backup_file)
    print(f"    Backed up old graph to: {backup_file}")

nx.write_gpickle(G, OUTPUT_FILE)

size = os.path.getsize(OUTPUT_FILE) / (1024*1024)
print(f"    Saved: {OUTPUT_FILE} ({size:.1f} MB)")

print("\n" + "=" * 60)
print(f"COMPLETE: {len(G.nodes())} nodes, {len(G.edges())} edges")
print("=" * 60)

# Test locations in Kerala
print("\nTesting locations in Kerala:")
test_locs = [
    ("Mannampatta", 10.8327, 76.4584),
    ("Ottapalam", 10.7722, 76.3347),
    ("Thiruvananthapuram", 8.5241, 76.9366),
    ("Kochi", 9.9312, 76.2673),
    ("Palakkad", 10.7867, 76.5854),
]

lats = [d.get('y', 0) for _, _, d in G.nodes(data=True)]
lons = [d.get('x', 0) for _, _, d in G.nodes(data=True)]
min_lat, max_lat = min(lats), max(lats)
min_lon, max_lon = min(lons), max(lons)

print(f"\nGraph bounds: Lat {min_lat:.4f}-{max_lat:.4f}, Lon {min_lon:.4f}-{max_lon:.4f}")

for name, lat, lon in test_locs:
    if min_lat <= lat <= max_lat and min_lon <= lon <= max_lon:
        print(f"  {name}: ✅ In coverage area")
    else:
        print(f"  {name}: ❌ OUTSIDE coverage area")

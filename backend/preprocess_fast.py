"""
Fast graph preprocessing using OSMnx download with proper attribute settings.
"""
import osmnx as ox
import networkx as nx
import os

# Configuration
OUTPUT_FILE = "backend/southern_zone_graph.gpickle"

# Southern India bounding box (Kerala and surrounding)
SOUTH_INDIA_BBOX = (8.0, 76.0, 13.0, 78.5)  # (north, south, east, west)

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
print("Fast OSM Graph Preprocessing")
print("=" * 60)

# Download with simplify=False to preserve attributes
print("\n[1/4] Downloading OSM data (driveable roads only)...")
G = ox.graph_from_bbox(
    bbox=SOUTH_INDIA_BBOX,
    network_type="drive",
    simplify=False  # IMPORTANT: Keep all attributes
)
print(f"    Downloaded: {len(G.nodes())} nodes, {len(G.edges())} edges")

# Add speed and travel time
print("\n[2/4] Computing speeds and travel times...")
for u, v, data in G.edges(data=True):
    highway = data.get('highway', 'road')
    speed = get_speed_kph(highway)
    data['speed_kph'] = speed
    
    length = data.get('length', 100.0)
    data['travel_time'] = (length / 1000) / (speed / 3.6) if speed > 0 else length / 10

# Sample edges
print("\n[3/4] Sample edge attributes...")
sample = list(G.edges(data=True))[:10]
print("\n" + "=" * 70)
for i, (u, v, d) in enumerate(sample):
    print(f"Edge {i+1}: {u}->{v}")
    print(f"  highway: {d.get('highway')}")
    print(f"  length: {d.get('length', 0):.1f}m, speed: {d.get('speed_kph', 0):.0f}km/h, time: {d.get('travel_time', 0):.1f}s")
print("=" * 70)

# Save
print("\n[4/4] Saving graph...")
nx.write_gpickle(G, OUTPUT_FILE)
size = os.path.getsize(OUTPUT_FILE) / (1024*1024)
print(f"    Saved: {OUTPUT_FILE} ({size:.1f} MB)")

print("\n" + "=" * 60)
print(f"COMPLETE: {len(G.nodes())} nodes, {len(G.edges())} edges")
print("=" * 60)

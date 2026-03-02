"""
Trivandrum area graph preprocessing using OSMnx - smaller region.
"""
import osmnx as ox
import networkx as nx
import os

OUTPUT_FILE = "backend/southern_zone_graph.gpickle"

# Trivandrum area - much smaller
TRIVANDRUM_BBOX = (8.5, 76.8, 8.7, 77.2)  # (north, south, east, west)

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
print("Trivandrum OSM Graph Preprocessing")
print("=" * 60)

print("\n[1/4] Downloading OSM data...")
G = ox.graph_from_bbox(
    bbox=TRIVANDRUM_BBOX,
    network_type="drive",
    simplify=False
)
print(f"    Downloaded: {len(G.nodes())} nodes, {len(G.edges())} edges")

print("\n[2/4] Computing speeds and travel times...")
for u, v, data in G.edges(data=True):
    highway = data.get('highway', 'road')
    speed = get_speed_kph(highway)
    data['speed_kph'] = speed
    length = data.get('length', 100.0)
    data['travel_time'] = (length / 1000) / (speed / 3.6) if speed > 0 else length / 10

print("\n[3/4] Sample edge attributes...")
sample = list(G.edges(data=True))[:5]
for i, (u, v, d) in enumerate(sample):
    print(f"  {u}->{v}: highway={d.get('highway')}, length={d.get('length',0):.0f}m, speed={d.get('speed_kph',0):.0f}km/h")

print("\n[4/4] Saving graph...")
nx.write_gpickle(G, OUTPUT_FILE)
size = os.path.getsize(OUTPUT_FILE) / (1024*1024)
print(f"    Saved: {OUTPUT_FILE} ({size:.1f} MB)")

print("\n" + "=" * 60)
print(f"COMPLETE: {len(G.nodes())} nodes, {len(G.edges())} edges")
print("=" * 60)

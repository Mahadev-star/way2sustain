"""
Expand OSM graph to cover ALL of Kerala.
This will regenerate the graph with a wider coverage area.
"""
import osmnx as ox
import networkx as nx
import os

# Configuration
OUTPUT_FILE = "backend/southern_zone_graph.gpickle"

# Full Kerala bounding box
# Kerala extends from ~8.5°N to ~12.5°N latitude and ~76°E to ~77.5°E longitude
# Adding some padding for complete coverage
KERALA_BBOX = (12.5, 8.5, 77.5, 76.0)  # (north, south, east, west)

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


def preprocess_full_kerala():
    print("=" * 60)
    print("FULL KERALA OSM GRAPH PREPROCESSING")
    print("=" * 60)
    print(f"\nBounding box: North={KERALA_BBOX[0]}, South={KERALA_BBOX[1]}")
    print(f"             East={KERALA_BBOX[2]}, West={KERALA_BBOX[3]}")
    
    # Download with simplify=False to preserve attributes
    print("\n[1/4] Downloading OSM data (driveable roads only)...")
    print("      This may take a few minutes...")
    
    try:
        G = ox.graph_from_bbox(
            bbox=KERALA_BBOX,
            network_type="drive",
            simplify=False  # IMPORTANT: Keep all attributes
        )
    except Exception as e:
        print(f"      Error: {e}")
        print("      Trying with smaller area...")
        # Try smaller area if the full download fails
        KERALA_BBOX = (12.0, 9.0, 77.3, 76.2)  # Smaller box
        G = ox.graph_from_bbox(
            bbox=KERALA_BBOX,
            network_type="drive",
            simplify=False
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
    
    return G


if __name__ == "__main__":
    preprocess_full_kerala()

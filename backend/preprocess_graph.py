"""
One-time preprocessing script to convert OSM PBF file to directed road graph.
Uses pyosmium to read PBF directly and preserves ALL attributes including highway.
"""

import osmium
import networkx as nx
import os
import math

# Configuration  
PBF_FILE = "assets/data/southern-zone-260228.osm (1).pbf"
OUTPUT_FILE = "backend/southern_zone_graph.gpickle"

# Default speed limits by highway type (km/h)
HIGHWAY_SPEED_LIMITS = {
    'motorway': 100,
    'motorway_link': 60,
    'trunk': 80,
    'trunk_link': 50,
    'primary': 65,
    'primary_link': 45,
    'secondary': 55,
    'secondary_link': 40,
    'tertiary': 45,
    'tertiary_link': 35,
    'residential': 30,
    'unclassified': 40,
    'living_street': 20,
    'service': 25,
    'road': 40,
}

# Driveable highway types
DRIVABLE = {'motorway', 'motorway_link', 'trunk', 'trunk_link', 'primary', 
             'primary_link', 'secondary', 'secondary_link', 'tertiary', 
             'tertiary_link', 'residential', 'unclassified', 'living_street', 
             'service', 'road'}


class OSMGraphBuilder(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.nodes = {}
        self.ways = []
        self.node_count = 0
        self.way_count = 0
        
    def node(self, n):
        self.nodes[n.id] = {'id': n.id, 'lat': n.location.lat, 'lon': n.location.lon}
        self.node_count += 1
        if self.node_count % 100000 == 0:
            print(f"    Processed {self.node_count} nodes...")
    
    def way(self, w):
        highway = w.tags.get('highway', '')
        if any(h in highway for h in DRIVABLE):
            nodes = [n.ref for n in w.nodes]
            if len(nodes) >= 2:
                self.ways.append({
                    'id': w.id,
                    'nodes': nodes,
                    'highway': highway,
                    'maxspeed': w.tags.get('maxspeed', ''),
                    'lanes': w.tags.get('lanes', '1'),
                    'name': w.tags.get('name', ''),
                })
                self.way_count += 1
                if self.way_count % 10000 == 0:
                    print(f"    Processed {self.way_count} driveable ways...")


def get_speed_kph(highway: str, maxspeed_tag: str) -> float:
    """Get speed from maxspeed tag or highway type"""
    if maxspeed_tag:
        try:
            if isinstance(maxspeed_tag, str):
                ms = maxspeed_tag.strip()
                if 'mph' in ms.lower():
                    return float(ms.split()[0]) * 1.60934
                return float(ms.split()[0])
            return float(maxspeed_tag)
        except:
            pass
    
    for hw, speed in HIGHWAY_SPEED_LIMITS.items():
        if hw in str(highway):
            return float(speed)
    return 40.0


def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))


def preprocess():
    print("=" * 60)
    print("OSM Graph Preprocessing with Attribute Preservation")
    print("=" * 60)
    
    # Step 1: Read PBF
    print("\n[1/5] Reading PBF with pyosmium...")
    print("    (This may take several minutes for large files)")
    
    builder = OSMGraphBuilder()
    builder.apply_file(PBF_FILE)
    
    print(f"    Found {len(builder.nodes)} nodes, {len(builder.ways)} driveable ways")
    
    # Step 2: Build graph
    print("\n[2/5] Building NetworkX graph...")
    
    G = nx.MultiDiGraph()
    
    # Add nodes
    for nid, data in builder.nodes.items():
        G.add_node(nid, y=data['lat'], x=data['lon'])
    
    # Add edges
    edge_count = 0
    for way in builder.ways:
        nodes = way['nodes']
        highway = way['highway']
        maxspeed_tag = way['maxspeed']
        
        speed_kph = get_speed_kph(highway, maxspeed_tag)
        
        for i in range(len(nodes) - 1):
            u, v = nodes[i], nodes[i+1]
            if u not in G.nodes() or v not in G.nodes():
                continue
            
            # Calculate distance
            u_data = G.nodes[u]
            v_data = G.nodes[v]
            dist = haversine(u_data['y'], u_data['x'], v_data['y'], v_data['x'])
            
            # Travel time
            travel_time = (dist / 1000) / (speed_kph / 3.6) if speed_kph > 0 else dist / 10
            
            # Emission
            emission = (dist / 1000) * 0.2
            
            attrs = {
                'highway': highway,
                'maxspeed': maxspeed_tag if maxspeed_tag else str(int(speed_kph)),
                'lanes': way['lanes'],
                'name': way['name'],
                'length': dist,
                'speed_kph': speed_kph,
                'travel_time': travel_time,
                'emission_kg': emission,
            }
            
            G.add_edge(u, v, **attrs)
            G.add_edge(v, u, **attrs)
            edge_count += 2
    
    print(f"    Built graph: {len(G.nodes())} nodes, {len(G.edges())} edges")
    
    # Step 3: Print sample edges
    print("\n[3/5] Sample edge attributes...")
    
    sample = list(G.edges(data=True))[:20]
    print("\n" + "=" * 70)
    for i, (u, v, d) in enumerate(sample):
        print(f"Edge {i+1}: {u} -> {v}")
        print(f"  highway: {d.get('highway')}")
        print(f"  maxspeed: {d.get('maxspeed')}")
        print(f"  length: {d.get('length', 0):.1f}m")
        print(f"  speed_kph: {d.get('speed_kph', 0):.1f}")
        print(f"  travel_time: {d.get('travel_time', 0):.2f}s")
        print(f"  emission: {d.get('emission_kg', 0):.4f}kg")
    print("=" * 70)
    
    # Step 4: Compute stats
    print("\n[4/5] Computing edge stats...")
    
    distances = [d.get('length', 0) for u, v, d in G.edges(data=True)]
    times = [d.get('travel_time', 0) for u, v, d in G.edges(data=True)]
    emissions = [d.get('emission_kg', 0) for u, v, d in G.edges(data=True)]
    speeds = [d.get('speed_kph', 40) for u, v, d in G.edges(data=True)]
    
    print(f"\nDistance: min={min(distances):.1f}m, max={max(distances):.1f}m, mean={sum(distances)/len(distances):.1f}m")
    print(f"Time: min={min(times):.2f}s, max={max(times):.2f}s, mean={sum(times)/len(times):.2f}s")
    print(f"Emission: min={min(emissions):.4f}kg, max={max(emissions):.4f}kg, mean={sum(emissions)/len(emissions):.4f}kg")
    print(f"Speed: min={min(speeds):.0f}km/h, max={max(speeds):.0f}km/h, mean={sum(speeds)/len(speeds):.0f}km/h")
    
    # Highway types
    highways = {}
    for u, v, d in G.edges(data=True):
        hw = d.get('highway', 'unknown')
        highways[hw] = highways.get(hw, 0) + 1
    print(f"\nHighway types: {dict(sorted(highways.items(), key=lambda x: -x[1])[:10])}")
    
    # Step 5: Save
    print("\n[5/5] Saving graph...")
    nx.write_gpickle(G, OUTPUT_FILE)
    
    size = os.path.getsize(OUTPUT_FILE) / (1024*1024)
    print(f"    Saved to: {OUTPUT_FILE}")
    print(f"    Size: {size:.2f} MB")
    
    print("\n" + "=" * 60)
    print("COMPLETE")
    print("=" * 60)
    print(f"Nodes: {len(G.nodes())}")
    print(f"Edges: {len(G.edges())}")
    print("=" * 60)
    
    return G


if __name__ == "__main__":
    G = preprocess()

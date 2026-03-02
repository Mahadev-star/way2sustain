"""
Process the full India PBF file to extract Kerala roads.
This will create a graph covering all of Kerala.
"""
import osmium
import networkx as nx
import os
import math

# Configuration  
PBF_FILE = "assets/data/india-260228.osm (1).pbf"
OUTPUT_FILE = "backend/southern_zone_graph.gpickle"

# Kerala bounding box (with some padding)
KERALA_MIN_LAT = 8.0
KERALA_MAX_LAT = 12.5
KERALA_MIN_LON = 76.0
KERALA_MAX_LON = 77.5

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


class KeralaOSMGraphBuilder(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.nodes = {}
        self.ways = []
        self.node_count = 0
        self.way_count = 0
        self.filtered_node_count = 0
        
    def node(self, n):
        # Only keep nodes within Kerala bounding box
        lat = n.location.lat
        lon = n.location.lon
        
        if KERALA_MIN_LAT <= lat <= KERALA_MAX_LAT and KERALA_MIN_LON <= lon <= KERALA_MAX_LON:
            self.nodes[n.id] = {'id': n.id, 'lat': lat, 'lon': lon}
            self.filtered_node_count += 1
        
        self.node_count += 1
        if self.node_count % 500000 == 0:
            print(f"    Processed {self.node_count} nodes (Kerala: {self.filtered_node_count})...")
    
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
    print("KERALA OSM GRAPH FROM INDIA PBF")
    print("=" * 60)
    print(f"\nKerala bounding box:")
    print(f"  Lat: {KERALA_MIN_LAT} to {KERALA_MAX_LAT}")
    print(f"  Lon: {KERALA_MIN_LON} to {KERALA_MAX_LON}")
    
    # Check if PBF file exists
    if not os.path.exists(PBF_FILE):
        print(f"\n❌ Error: PBF file not found: {PBF_FILE}")
        return None
    
    file_size = os.path.getsize(PBF_FILE) / (1024*1024*1024)
    print(f"  PBF file size: {file_size:.2f} GB")
    
    # Step 1: Read PBF
    print("\n[1/5] Reading India PBF with pyosmium...")
    print("    (This will take several minutes for large file)...")
    
    builder = KeralaOSMGraphBuilder()
    builder.apply_file(PBF_FILE)
    
    print(f"    Total nodes in file: {builder.node_count}")
    print(f"    Nodes in Kerala: {len(builder.nodes)}")
    print(f"    Driveable ways: {len(builder.ways)}")
    
    # Step 2: Build graph
    print("\n[2/5] Building NetworkX graph...")
    
    G = nx.MultiDiGraph()
    
    # Add nodes
    for nid, data in builder.nodes.items():
        G.add_node(nid, y=data['lat'], x=data['lon'])
    
    print(f"    Added {len(G.nodes())} nodes")
    
    # Add edges
    edge_count = 0
    valid_way_count = 0
    
    for way in builder.ways:
        nodes = way['nodes']
        highway = way['highway']
        maxspeed_tag = way['maxspeed']
        
        # Check if all nodes are in our Kerala graph
        valid_nodes = [n for n in nodes if n in G.nodes()]
        
        if len(valid_nodes) < 2:
            continue
            
        valid_way_count += 1
        speed_kph = get_speed_kph(highway, maxspeed_tag)
        
        for i in range(len(valid_nodes) - 1):
            u, v = valid_nodes[i], valid_nodes[i+1]
            
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
    
    print(f"    Valid ways: {valid_way_count}")
    print(f"    Built graph: {len(G.nodes())} nodes, {len(G.edges())} edges")
    
    # Step 3: Print sample edges
    print("\n[3/5] Sample edge attributes...")
    
    sample = list(G.edges(data=True))[:20]
    print("\n" + "=" * 70)
    for i, (u, v, d) in enumerate(sample):
        print(f"Edge {i+1}: {u} -> {v}")
        print(f"  highway: {d.get('highway')}")
        print(f"  length: {d.get('length', 0):.1f}m")
        print(f"  speed: {d.get('speed_kph', 0):.0f} km/h")
    print("=" * 70)
    
    # Step 4: Compute stats
    print("\n[4/5] Computing edge stats...")
    
    distances = [d.get('length', 0) for u, v, d in G.edges(data=True)]
    times = [d.get('travel_time', 0) for u, v, d in G.edges(data=True)]
    emissions = [d.get('emission_kg', 0) for u, v, d in G.edges(data=True)]
    
    if distances:
        print(f"\nDistance: min={min(distances):.1f}m, max={max(distances):.1f}m, mean={sum(distances)/len(distances):.1f}m")
        print(f"Time: min={min(times):.2f}s, max={max(times):.2f}s, mean={sum(times)/len(times):.2f}s")
        print(f"Emission: min={min(emissions):.4f}kg, max={max(emissions):.4f}kg, mean={sum(emissions)/len(emissions):.4f}kg")
    
    # Highway types
    highways = {}
    for u, v, d in G.edges(data=True):
        hw = d.get('highway', 'unknown')
        highways[hw] = highways.get(hw, 0) + 1
    print(f"\nHighway types: {dict(sorted(highways.items(), key=lambda x: -x[1])[:10])}")
    
    # Step 5: Save
    print("\n[5/5] Saving graph...")
    
    # Backup old graph
    if os.path.exists(OUTPUT_FILE):
        backup_file = OUTPUT_FILE.replace('.gpickle', '_backup.gpickle')
        os.rename(OUTPUT_FILE, backup_file)
        print(f"    Backed up old graph to: {backup_file}")
    
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
    preprocess()

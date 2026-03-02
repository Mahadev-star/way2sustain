"""Check the existing graph file."""
import pickle
import os

GRAPH_FILE = "backend/southern_zone_graph.gpickle"

print("Loading graph...")
with open(GRAPH_FILE, 'rb') as f:
    G = pickle.load(f)

print(f"\nGraph Stats:")
print(f"  Nodes: {len(G.nodes())}")
print(f"  Edges: {len(G.edges())}")

# Check sample edge attributes
print("\nSample edges:")
sample = list(G.edges(data=True))[:10]
for i, (u, v, d) in enumerate(sample):
    print(f"  {u}->{v}:")
    print(f"    highway: {d.get('highway')}")
    print(f"    length: {d.get('length')}")
    print(f"    speed_kph: {d.get('speed_kph')}")
    print(f"    travel_time: {d.get('travel_time')}")

# File size
size = os.path.getsize(GRAPH_FILE)
print(f"\nFile size: {size / (1024*1024):.2f} MB")

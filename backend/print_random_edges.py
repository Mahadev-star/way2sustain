"""Print 20 random edges from the graph."""
import pickle
import random

GRAPH_FILE = "backend/southern_zone_graph.gpickle"

print("Loading graph...")
with open(GRAPH_FILE, 'rb') as f:
    G = pickle.load(f)

print(f"\nTotal edges: {len(G.edges())}")
print("\n" + "="*80)
print("20 RANDOM EDGES:")
print("="*80)
print(f"{'#':<3} {'highway':<20} {'length (m)':<12} {'speed_kph':<12} {'travel_time (s)':<15}")
print("-"*80)

edges = list(G.edges(data=True))
random.seed(42)
random_edges = random.sample(edges, min(20, len(edges)))

for i, (u, v, d) in enumerate(random_edges, 1):
    highway = d.get('highway', 'N/A')
    length = d.get('length', 0)
    speed_kph = d.get('speed_kph', 0)
    travel_time = d.get('travel_time', 0)
    print(f"{i:<3} {highway:<20} {length:<12.2f} {speed_kph:<12.2f} {travel_time:<15.2f}")

print("="*80)

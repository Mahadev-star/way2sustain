"""Verify the graph."""
import pickle
import os

GRAPH_FILE = "backend/southern_zone_graph.gpickle"

with open(GRAPH_FILE, 'rb') as f:
    G = pickle.load(f)

print(f"Nodes: {len(G.nodes())}")
print(f"Edges: {len(G.edges())}")
print(f"File size: {os.path.getsize(GRAPH_FILE)/1024/1024:.2f} MB")

# Check sample edge attributes
u, v, d = next(iter(G.edges(data=True)))
print(f"Sample edge keys: {list(d.keys())}")

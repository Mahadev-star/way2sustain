"""Add emission_kg to graph edges and save."""
import pickle

GRAPH_FILE = "backend/southern_zone_graph.gpickle"
OUTPUT_FILE = "backend/southern_zone_graph.gpickle"

print("Loading graph...")
with open(GRAPH_FILE, 'rb') as f:
    G = pickle.load(f)

def get_emission_factor(speed_kph):
    """Speed-based emission factor in kg CO2 per km"""
    if speed_kph < 30:
        return 0.22
    elif speed_kph < 50:
        return 0.18
    elif speed_kph < 70:
        return 0.20
    else:
        return 0.25

print("Adding emission_kg to edges...")
for u, v, data in G.edges(data=True):
    length = data.get('length', 100)
    speed_kph = data.get('speed_kph', 40)
    length_km = length / 1000
    
    emission_factor = get_emission_factor(speed_kph)
    emission_kg = length_km * emission_factor
    
    data['emission_kg'] = emission_kg

print("Saving graph...")
with open(OUTPUT_FILE, 'wb') as f:
    pickle.dump(G, f)

print("Done!")

# Verify
u, v, d = next(iter(G.edges(data=True)))
print(f"Sample edge keys: {list(d.keys())}")

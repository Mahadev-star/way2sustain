"""Compute edge costs with speed-dependent emission model - using percentiles."""
import pickle
import numpy as np

GRAPH_FILE = "backend/southern_zone_graph.gpickle"

print("Loading graph...")
with open(GRAPH_FILE, 'rb') as f:
    G = pickle.load(f)

print("\n=== STEP 1: Add emission_kg to edges ===")

def get_emission_factor(speed_kph):
    """Speed-based emission factor in kg CO2 per km"""
    if speed_kph < 30:
        return 0.22  # city traffic - inefficient
    elif speed_kph < 50:
        return 0.18  # normal - most efficient
    elif speed_kph < 70:
        return 0.20  # highway
    else:
        return 0.25  # fast - less efficient

# Add emission_kg to all edges
for u, v, data in G.edges(data=True):
    length = data.get('length', 100)
    speed_kph = data.get('speed_kph', 40)
    length_km = length / 1000
    
    emission_factor = get_emission_factor(speed_kph)
    emission_kg = length_km * emission_factor
    
    data['emission_kg'] = emission_kg

print("Emission values added to edges")

print("\n=== STEP 2: Compute global stats ===")

# Collect all edge attributes
lengths = []
travel_times = []
emissions = []

for u, v, data in G.edges(data=True):
    lengths.append(data.get('length', 100))
    travel_times.append(data.get('travel_time', 10))
    emissions.append(data.get('emission_kg', 0))

print(f"length: min={min(lengths):.2f}, max={max(lengths):.2f}, mean={np.mean(lengths):.2f}")
print(f"travel_time: min={min(travel_times):.2f}, max={max(travel_times):.2f}, mean={np.mean(travel_times):.2f}")
print(f"emission_kg: min={min(emissions):.4f}, max={max(emissions):.4f}, mean={np.mean(emissions):.4f}")

# Use percentile-based normalization (5th-95th percentile to avoid outliers)
length_p5, length_p95 = np.percentile(lengths, 5), np.percentile(lengths, 95)
time_p5, time_p95 = np.percentile(travel_times, 5), np.percentile(travel_times, 95)
emission_p5, emission_p95 = np.percentile(emissions, 5), np.percentile(emissions, 95)

print(f"\nUsing 5th-95th percentile normalization:")
print(f"length: {length_p5:.2f} - {length_p95:.2f}")
print(f"time: {time_p5:.2f} - {time_p95:.2f}")
print(f"emission: {emission_p5:.4f} - {emission_p95:.4f}")

print("\n=== STEP 3: Compute normalized costs ===")

eco_costs = []
balanced_costs = []
quickest_costs = []

for u, v, data in G.edges(data=True):
    length = data.get('length', 100)
    travel_time = data.get('travel_time', 10)
    emission_kg = data.get('emission_kg', 0)
    
    # Normalize using percentiles
    eps = 0.0001
    length_norm = (length - length_p5) / (length_p95 - length_p5 + eps)
    time_norm = (travel_time - time_p5) / (time_p95 - time_p5 + eps)
    emission_norm = (emission_kg - emission_p5) / (emission_p95 - emission_p5 + eps)
    
    # Clip to [0, 1]
    length_norm = max(0, min(1, length_norm))
    time_norm = max(0, min(1, time_norm))
    emission_norm = max(0, min(1, emission_norm))
    
    # Compute route costs
    eco_cost = 0.6 * emission_norm + 0.3 * length_norm + 0.1 * time_norm
    balanced_cost = 0.33 * emission_norm + 0.33 * length_norm + 0.34 * time_norm
    quickest_cost = 0.7 * time_norm + 0.2 * length_norm + 0.1 * emission_norm
    
    eco_costs.append(eco_cost)
    balanced_costs.append(balanced_cost)
    quickest_costs.append(quickest_cost)

print("\n=== STEP 4: Cost Statistics ===")
print(f"Eco:       Min={min(eco_costs):.4f} Max={max(eco_costs):.4f} Mean={np.mean(eco_costs):.4f}")
print(f"Balanced:  Min={min(balanced_costs):.4f} Max={max(balanced_costs):.4f} Mean={np.mean(balanced_costs):.4f}")
print(f"Quickest:  Min={min(quickest_costs):.4f} Max={max(quickest_costs):.4f} Mean={np.mean(quickest_costs):.4f}")

print("\n=== EMISSION MODEL USED ===")
print("emission_kg = length_km × emission_factor")
print("where emission_factor depends on speed_kph:")
print("  speed_kph < 30: 0.22 kg/km (city traffic)")
print("  30 <= speed_kph < 50: 0.18 kg/km (most efficient)")
print("  50 <= speed_kph < 70: 0.20 kg/km (highway)")
print("  speed_kph >= 70: 0.25 kg/km (fast - less efficient)")

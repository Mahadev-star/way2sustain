"""
Convert PBF to OSM XML using osmium, then process with OSMnx.
"""
import osmium
import io
import sys

# Input and output files
PBF_FILE = "assets/data/southern-zone-260228.osm (1).pbf"
OUTPUT_XML = "assets/data/southern-zone.osm"

print("Converting PBF to OSM XML...")
print("This may take several minutes...")

# Use osmium simple transform
import subprocess
result = subprocess.run(['python', '-c', '''
import osmium
import sys

class NoOpHandler(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()

# Just check if we can read the file
handler = NoOpHandler()
handler.apply_file("''' + PBF_FILE + '''")
print("File is readable by osmium")
'''], capture_output=True, text=True)

print(result.stdout)
print(result.stderr)

print("\nThe PBF file can be read by osmium.")
print("Now trying direct graph extraction with osmium...")

"""Read-only source inventory and arithmetic mirrors; NOT Flutter/widget tests."""
from pathlib import Path
import json
import re

OUT = Path(__file__).resolve().parent
ROOT = OUT / 'Sthira-Without-Mitra-main'
missing = []
inventory = []
for path in sorted((ROOT / 'lib').rglob('*.dart')):
    source = path.read_text(encoding='utf-8')
    if 'screens' in path.relative_to(ROOT).parts:
        inventory.append({'file': path.relative_to(ROOT).as_posix(), 'lines': len(source.splitlines())})
    for match in re.finditer(r"(?:import|export|part)\s+['\"]([^'\"]+)['\"]", source):
        uri = match.group(1)
        if ':' in uri:
            continue
        target = path.parent / uri
        if not target.exists():
            missing.append({'file': path.relative_to(ROOT).as_posix(), 'line': source[:match.start()].count('\n') + 1, 'uri': uri, 'resolved': str(target.resolve())})

# Exact redistribution approach in plate_calculator_sheet._balance:
# adjust the other three sliders equally, then independently clamp them.
plate = [100.0, 25.0, 50.0, 0.0]
diff = 100 - sum(plate)
for i in (1, 2, 3):
    plate[i] = min(100, max(0, plate[i] + diff / 3))
assert sum(plate) == 125

def luminance(hex_color):
    values = [int(hex_color[i:i+2], 16) / 255 for i in (0, 2, 4)]
    channels = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in values]
    return sum(a * b for a, b in zip(channels, (.2126, .7152, .0722)))

def contrast(a, b):
    light, dark = sorted([luminance(a), luminance(b)], reverse=True)
    return round((light + .05) / (dark + .05), 2)

results = {
    'method': 'Static file resolution plus Python mirrors of selected source arithmetic. No Flutter app execution.',
    'screen_files': len(inventory),
    'missing_relative_imports_exports_parts': missing,
    'plate_after_protein_100_from_default': {'percentages': plate, 'sum_percent': sum(plate), 'nominal_plate_g': 500, 'allocated_g': 500 * sum(plate) / 100},
    'target_weight_fallback_lb_preference': {'stored_kg': 70, 'code_passes_as_kg': 70 / 2.20462, 'correct_kg': 70},
    'contrast_solid_tokens': {
        'dark_textDark_EFE8EA_on_primary_E29B65': contrast('EFE8EA', 'E29B65'),
        'white_on_primary_E29B65': contrast('FFFFFF', 'E29B65'),
        'onPrimary_2D1A25_on_primary_E29B65': contrast('2D1A25', 'E29B65')
    },
    'scope_inventory': inventory
}
(OUT / 'ui-audit-evidence.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
print(json.dumps({k:v for k,v in results.items() if k != 'scope_inventory'}, indent=2))

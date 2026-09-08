"""Offline reproduction of selected Dart logic, not an execution of Flutter.

Uses the ZIP's actual nutrition table. No network, credentials, or app DB.
The matcher/parser below mirrors the inspected ASCII paths only.
"""
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TABLE = json.loads((ROOT / 'Sthira-Without-Mitra-main/assets/data/nutrition_table.json').read_text(encoding='utf-8'))


def tokens(value):
    return re.sub(r'[^\w\s]', ' ', value.lower(), flags=re.ASCII).split()


def match_food(query):
    qt = tokens(query)
    if not qt:
        return None
    qs = ' '.join(qt)
    for item in TABLE:
        if ' '.join(tokens(item['name'])) == qs:
            return item
    for item in TABLE:
        if any(' '.join(tokens(a)) == qs for a in item.get('aliases', [])):
            return item
    candidates = []
    for item in TABLE:
        nt = tokens(item['name'])
        count = len(nt) if nt and all(t in qt for t in nt) else 0
        if not count:
            for alias in item.get('aliases', []):
                at = tokens(alias)
                if not at:
                    continue
                if len(at) == 1:
                    non_neutral = [t for t in qt if t not in {'plain', 'steamed', 'white', 'cooked'}]
                    success = len(non_neutral) == 1 and non_neutral[0] == at[0]
                else:
                    success = all(t in qt for t in at)
                if success:
                    count = len(at)
                    break
        if count:
            candidates.append((count, len(item['name']), item))
    candidates.sort(key=lambda c: (c[0], c[1]), reverse=True)
    return candidates[0][2] if candidates else None


def local_result(description):
    part = description.lower().strip()
    parsed = re.match(r'^(\d+(?:\.\d+)?)\s*(bowl|cup|plate|piece|idlis?|dosas?|chapatis?|rotis?|tbsp|tsp)?\s*(.*)$', part, re.I)
    query, quantity = part, 1.0
    if parsed:
        quantity = float(parsed[1])
        if parsed[3].strip():
            query = parsed[3].strip()
        elif parsed[2]:
            query = parsed[2]
    if query.endswith('s') and not query.endswith('ss'):
        query = query[:-1]
    item = match_food(query)
    if not item:
        return {'input': description, 'matched': None, 'path': 'AI required'}
    grams = item.get('defaultPortionG', 100) * quantity
    multiplier = grams / 100 if item.get('is_per_100g') is True else quantity
    values = item['per100g']
    energy = (4 * values['protein_g'] + 4 * values['carbs_g'] + 9 * values['fat_g']) * multiplier
    kcal = values['kcal'] * multiplier
    if kcal == 0 or abs(kcal - energy) > 25:
        kcal = energy
    return {'input': description, 'matched': item['name'], 'estimated_grams': grams,
            'current_kcal': math.floor(kcal + 0.5),
            'table_kcal_at_returned_grams': values['kcal'] * grams / 100,
            'confidence': 'high'}


cases = [local_result(q) for q in [
    '1 bowl white rice', '1 bowl chicken biryani', '2 chapatis', '2 idlis',
    '200 g white rice', '1 tsp sambar', '1 cup sambar',
    '1 white rice with butter', '1 dosa with cheese', '1 bowl sambar',
]]
by_input = {r['input']: r for r in cases}
assert by_input['1 bowl white rice']['current_kcal'] == 130
assert by_input['1 bowl white rice']['table_kcal_at_returned_grams'] == 195
assert by_input['1 bowl chicken biryani']['current_kcal'] == 180
assert by_input['2 chapatis']['current_kcal'] == 570
assert by_input['2 idlis']['estimated_grams'] == 200
assert by_input['200 g white rice']['current_kcal'] == 25100
assert by_input['1 tsp sambar']['current_kcal'] == by_input['1 cup sambar']['current_kcal']
assert by_input['1 white rice with butter']['matched'] == 'White Rice'
assert by_input['1 dosa with cheese']['path'] == 'AI required'

summary = {
    'method': 'Python reproduction of inspected Dart arithmetic and ASCII parser; not app execution or clinical ground truth',
    'table_rows': len(TABLE),
    'estimated_rows': sum(i.get('estimated') is True for i in TABLE),
    'rows_with_explicit_basis_flag': sum('is_per_100g' in i for i in TABLE),
    'cases': cases,
    'additional_arithmetic_checks': {
        'two_idlis_using_prompt_40g_each_and_table_150kcal_per100g': 2 * 40 * 150 / 100,
        'saved_300kcal_per_150g_serving_at_150g_photo_current': 300 * 150 / 100,
        'saved_300kcal_per_150g_serving_at_150g_correct': 300,
        'fallback_individual_clamps_allow_total_macro_g_per100g': 100 + 100 + 100,
        'fallback_energy_for_that_invalid_combination': 4 * 100 + 4 * 100 + 9 * 100,
    },
}
output = ROOT / 'reproduction-results.json'
output.write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
print(json.dumps(summary, indent=2))

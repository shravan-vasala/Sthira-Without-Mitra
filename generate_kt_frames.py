import sys
import re
import os

# Mitra
with open('lib/widgets/gen_frames_48.dart', 'r') as f:
    dart_code = f.read()

matches = re.findall(r'final _([a-zA-Z0-9_]+) = _parseFrame\(\s*\'\'\'(.*?)\'\'\',', dart_code, re.DOTALL)

kt_code = "package com.trufit.trufit_bodamma\n\nobject MitraFrames {\n"
kt_code += "    val frames = mapOf(\n"
for name, content in matches:
    content = content.replace("'", "").strip()
    kt_code += f"        \"{name}\" to \"\"\"{content}\"\"\",\n"
kt_code += "    )\n}\n"

with open('android/app/src/main/kotlin/com/trufit/trufit_bodamma/MitraFrames.kt', 'w') as f:
    f.write(kt_code)

# Sunflower
with open('lib/widgets/gen_sunflower_48.dart', 'r') as f:
    sunflower_code = f.read()

sun_matches = re.findall(r'const List<String> _([a-zA-Z0-9_]+) = \[\s*(.*?)\s*\];', sunflower_code, re.DOTALL)
kt_sun_code = "package com.trufit.trufit_bodamma\n\nobject SunflowerFrames {\n"
kt_sun_code += "    val frames = mapOf(\n"
for name, content in sun_matches:
    # clean up the list of strings to one single string block
    content = content.replace("'", "").replace(",", "").replace(" ", "").strip()
    kt_sun_code += f"        \"{name}\" to \"\"\"{content}\"\"\",\n"
kt_sun_code += "    )\n}\n"

with open('android/app/src/main/kotlin/com/trufit/trufit_bodamma/SunflowerFrames.kt', 'w') as f:
    f.write(kt_sun_code)

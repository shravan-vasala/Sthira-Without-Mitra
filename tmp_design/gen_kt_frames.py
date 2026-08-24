import json
from gen_frames import dart_states

out = """package com.trufit.trufit_bodamma

object MitraFrames {
    // GENERATED 48x48 HANDCRAFTED ELEPHANT SILHOUETTES
"""

for k, v in dart_states.items():
    s = v.replace("\n", "").replace(" ", "")
    out += f'    const val {k.upper()} = "{s}"\n'

out += "}\n"

with open("c:/Users/sande/OneDrive/Desktop/trufit-another/trufit-bodamma-another-copy/android/app/src/main/kotlin/com/trufit/trufit_bodamma/MitraFrames.kt", "w", encoding="utf-8") as f:
    f.write(out)

print("Kotlin frames generated!")

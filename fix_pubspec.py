import re

file_path = "pubspec.yaml"
with open(file_path, "r", encoding="utf-8") as f:
    code = f.read()

code = re.sub(r'firebase_ai: \^2\.3\.0', r'firebase_ai: any', code)
code = re.sub(r'googleai_dart: \^11\.0\.0', r'googleai_dart: any', code)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(code)

print("Updated pubspec.yaml")

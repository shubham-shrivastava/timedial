#!/bin/bash
set -euo pipefail

PROJECT="timedial.xcodeproj/project.pbxproj"

usage() {
  cat <<'EOF'
Usage:
  ./bump_version.sh <marketing_version> [build_number]
  ./bump_version.sh --show

Examples:
  ./bump_version.sh 1.0.1
  ./bump_version.sh 1.0.2 5
EOF
}

if [ "${1:-}" = "--show" ]; then
  python3 - <<'PY'
import re
path = "timedial.xcodeproj/project.pbxproj"
data = open(path, "r", encoding="utf-8").read()
mv = re.search(r"MARKETING_VERSION = ([^;]+);", data)
bv = re.search(r"CURRENT_PROJECT_VERSION = ([^;]+);", data)
print(f"MARKETING_VERSION={mv.group(1) if mv else 'unknown'}")
print(f"CURRENT_PROJECT_VERSION={bv.group(1) if bv else 'unknown'}")
PY
  exit 0
fi

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  usage
  exit 1
fi

MARKETING_VERSION="$1"

current_build=$(
  python3 - <<'PY'
import re
data = open("timedial.xcodeproj/project.pbxproj", "r", encoding="utf-8").read()
m = re.search(r"CURRENT_PROJECT_VERSION = ([^;]+);", data)
print(m.group(1).strip() if m else "0")
PY
)

if [ $# -eq 2 ]; then
  BUILD_NUMBER="$2"
else
  BUILD_NUMBER=$((current_build + 1))
fi

python3 - <<PY
import re
path = "timedial.xcodeproj/project.pbxproj"
data = open(path, "r", encoding="utf-8").read()
data = re.sub(r"(MARKETING_VERSION = )[^;]+;", r"\\g<1>${MARKETING_VERSION};", data)
data = re.sub(r"(CURRENT_PROJECT_VERSION = )[^;]+;", r"\\g<1>${BUILD_NUMBER};", data)
open(path, "w", encoding="utf-8").write(data)
print("Updated MARKETING_VERSION=${MARKETING_VERSION}")
print("Updated CURRENT_PROJECT_VERSION=${BUILD_NUMBER}")
PY

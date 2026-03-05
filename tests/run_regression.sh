#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RUN_QUARTUS=0
ALLOW_MISSING_REQUIRED_ROMS=0

for arg in "$@"; do
  case "$arg" in
    --quartus-compile)
      RUN_QUARTUS=1
      ;;
    --allow-missing-required-roms)
      ALLOW_MISSING_REQUIRED_ROMS=1
      ;;
    -h|--help)
      cat <<'EOF'
Usage: tests/run_regression.sh [--quartus-compile] [--allow-missing-required-roms]

Automated baseline checks for this repository.
  --quartus-compile   Run optional Quartus compile step (slow).
  --allow-missing-required-roms
                     Downgrade missing required ROM patterns to warnings.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
  echo "[PASS] $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "[FAIL] $1" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
  echo "[WARN] $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

check_merge_markers() {
  local hits
  hits="$(rg -n --hidden --glob '!.git/*' '^(<<<<<<< |>>>>>>> |=======$)' . || true)"
  if [[ -n "$hits" ]]; then
    echo "$hits"
    fail "Merge conflict markers found in repository"
    return 1
  fi
  pass "No merge conflict markers"
}

parse_qip_paths() {
  local qip_file="$1"
  local qip_dir
  qip_dir="$(cd "$(dirname "$qip_file")" && pwd)"

  awk '
    /set_global_assignment[[:space:]]+-name[[:space:]]+[A-Z_]+_FILE[[:space:]]+/ {
      line=$0
      if (line ~ /\[file join /) {
        sub(/^.*\[file join [^ ]+ /, "", line)
        sub(/ \].*$/, "", line)
        print "JOIN\t" line
      } else {
        n=split(line, a, /[[:space:]]+/)
        print "RAW\t" a[n]
      }
    }
  ' "$qip_file" | while IFS=$'\t' read -r kind relpath; do
    if [[ "$kind" == "JOIN" ]]; then
      printf '%s/%s\n' "$qip_dir" "$relpath"
    else
      if [[ "$relpath" == /* ]]; then
        printf '%s\n' "$relpath"
      else
        printf '%s/%s\n' "$ROOT_DIR" "$relpath"
      fi
    fi
  done
}

check_project_file_refs() {
  local -a check_files=(
    "$ROOT_DIR/files.qip"
    "$ROOT_DIR/rtl/N64.qip"
  )
  local missing=0

  for qip in "${check_files[@]}"; do
    if [[ ! -f "$qip" ]]; then
      echo "$qip"
      fail "Missing project file list: $qip"
      return 1
    fi
  done

  while IFS= read -r path; do
    if [[ -z "$path" ]]; then
      continue
    fi
    if [[ ! -e "$path" ]]; then
      echo "Missing: $path"
      missing=1
    fi
  done < <(
    parse_qip_paths "$ROOT_DIR/files.qip"
    parse_qip_paths "$ROOT_DIR/rtl/N64.qip"
  )

  if [[ "$missing" -eq 1 ]]; then
    fail "One or more project-referenced files are missing"
    return 1
  fi

  pass "All project-referenced files exist"
}

check_test_rom_manifest() {
  local manifest="$ROOT_DIR/tests/manifest/test_roms.tsv"
  local rom_dir="$ROOT_DIR/tests/roms"
  local required_missing=0
  local found_any=0

  if [[ ! -f "$manifest" ]]; then
    fail "Missing test ROM manifest: $manifest"
    return 1
  fi

  shopt -s nullglob
  while IFS=$'\t' read -r pattern required description; do
    [[ -z "${pattern:-}" || "${pattern:0:1}" == "#" ]] && continue
    local matches=( "$rom_dir"/$pattern )
    if (( ${#matches[@]} > 0 )); then
      echo "[INFO] ROM found for '$description': ${matches[0]##*/}"
      found_any=1
    else
      if [[ "$required" == "yes" ]]; then
        echo "[INFO] Missing required ROM pattern: $pattern ($description)"
        required_missing=1
      else
        echo "[INFO] Missing optional ROM pattern: $pattern ($description)"
      fi
    fi
  done < "$manifest"
  shopt -u nullglob

  if [[ "$required_missing" -eq 1 ]]; then
    if [[ "$ALLOW_MISSING_REQUIRED_ROMS" -eq 1 ]]; then
      warn "Required test ROMs are missing (allowed by flag)"
    else
      fail "Required test ROMs are missing (see tests/manifest/test_roms.tsv)"
      return 1
    fi
  fi

  if [[ "$found_any" -eq 0 ]]; then
    warn "No test ROMs found under tests/roms/"
  else
    pass "Test ROM manifest check"
  fi
}

run_quartus_compile() {
  if [[ "$RUN_QUARTUS" -eq 0 ]]; then
    warn "Quartus compile skipped (pass --quartus-compile to enable)"
    return 0
  fi

  if ! command -v quartus_sh >/dev/null 2>&1; then
    fail "quartus_sh not found in PATH"
    return 1
  fi

  echo "[INFO] Running Quartus compile (this may take a while)..."
  if quartus_sh --flow compile N64 -c N64; then
    pass "Quartus compile completed"
  else
    fail "Quartus compile failed"
    return 1
  fi
}

echo "== N64_MiSTer Regression =="
check_merge_markers || true
check_project_file_refs || true
check_test_rom_manifest || true
run_quartus_compile || true

echo
echo "Summary: PASS=$PASS_COUNT WARN=$WARN_COUNT FAIL=$FAIL_COUNT"

if [[ "$FAIL_COUNT" -ne 0 ]]; then
  exit 1
fi

exit 0

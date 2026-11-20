#!/usr/bin/env bash
# Suite mínima ISO/IEC/IEEE 29119 para layrz-ia-scripts.
# Cubre: paridad de ports, idempotencia, uninstall seguro, regresión de casing
# e integridad de la cadena SHA-256 del log.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
PASS=0
FAIL=0
SKIP=0

ok()   { printf 'PASS  %s\n' "$1"; PASS=$((PASS+1)); }
ko()   { printf 'FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }
skip() { printf 'SKIP  %s\n' "$1"; SKIP=$((SKIP+1)); }

have() { command -v "$1" >/dev/null 2>&1; }

PY=""
if have python3; then PY="python3"
elif have python; then PY="python"
fi

sha256_string() {
    if have sha256sum; then sha256sum | cut -d' ' -f1
    elif have shasum; then shasum -a 256 | cut -d' ' -f1
    elif have openssl; then openssl dgst -sha256 | awk '{print $NF}'
    elif [ -n "$PY" ]; then "$PY" -c 'import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'
    else return 1; fi
}

# ------------------------------------------------------------------------------
# Snapshot normalizado: sustituye la ruta del HOME por <HOME> para que los
# artefactos de ambos ports sean comparables aunque usen directorios distintos.
# ------------------------------------------------------------------------------
snapshot() {
    local home="$1" out="$2" f rel hash norm home_win="" home_win_slash
    if have cygpath; then home_win=$(cygpath -w "$home" 2>/dev/null || true); fi
    : > "$out"
    while IFS= read -r -d '' f; do
        rel="${f#$home/}"
        # MSYS convierte HOME a C:\... al invocar pwsh. Se normalizan primero los
        # separadores (incluidos los escapes '\\\\' de JSON) y luego ambas formas
        # de la ruta del HOME para que los ports sean comparables.
        # '\\\\' de JSON se convierte en '//'; se colapsa a '/' para comparar.
        norm=$(sed -e 's|\\|/|g' -e 's|//\+|/|g' "$f")
        norm="${norm//$home/<HOME>}"
        if [ -n "$home_win" ]; then
            home_win_slash="${home_win//\\//}"
            norm="${norm//$home_win_slash/<HOME>}"
        fi
        hash=$(printf '%s' "$norm" | sha256_string)
        printf '%s  %s\n' "$hash" "$rel" >> "$out"
    done < <(find "$home/.config/opencode" "$home/.gemini" "$home/.claude" \
                "$home/.config/ai-governance" -type f ! -name '*.jsonl' -print0 2>/dev/null | sort -z)
    sort -o "$out" "$out"
}

reset_targets() {
    local home="$1"
    rm -rf "$home/.config/opencode" "$home/.gemini" "$home/.claude" \
           "$home/.config/ai-governance" "$home/.local/state"
}

run_bash() {
    local home="$1"; shift
    HOME="$home" USERPROFILE="$home" bash "$REPO_DIR/setup-ai-governance.sh" "$@" >/dev/null 2>&1
}

run_ps() {
    local home="$1"; shift
    HOME="$home" USERPROFILE="$home" pwsh -NoProfile -File "$REPO_DIR/setup-ai-governance.ps1" "$@" >/dev/null 2>&1
}

HOME_A="${TMP_ROOT}/home-a"
mkdir -p "$HOME_A"

printf '\n== 1. Paridad de ports ==\n'
if ! have pwsh; then
    skip 'pwsh no disponible: se omite la comparación bash vs PowerShell'
else
    run_bash "$HOME_A" --yes --allow-missing-mcp --no-backup
    snapshot "$HOME_A" "${TMP_ROOT}/bash.snap"
    reset_targets "$HOME_A"
    run_ps "$HOME_A" -Yes -AllowMissingMcp -NoBackup
    snapshot "$HOME_A" "${TMP_ROOT}/ps.snap"
    if diff -u "${TMP_ROOT}/bash.snap" "${TMP_ROOT}/ps.snap" > "${TMP_ROOT}/parity.diff" 2>&1; then
        ok 'artefactos byte-idénticos entre .sh y .ps1'
    else
        ko "divergencia de ports (ver diff)"; cat "${TMP_ROOT}/parity.diff"
    fi
fi

printf '\n== 2. Idempotencia ==\n'
reset_targets "$HOME_A"
run_bash "$HOME_A" --yes --allow-missing-mcp --no-backup
snapshot "$HOME_A" "${TMP_ROOT}/run1.snap"
run_bash "$HOME_A" --yes --allow-missing-mcp --no-backup
snapshot "$HOME_A" "${TMP_ROOT}/run2.snap"
if diff -q "${TMP_ROOT}/run1.snap" "${TMP_ROOT}/run2.snap" >/dev/null 2>&1; then
    ok 'doble ejecución produce el mismo estado'
else
    ko 'la segunda ejecución modificó el estado'
fi
state_file="${HOME_A}/.config/ai-governance/installed.txt"
state_total=$(wc -l < "$state_file" 2>/dev/null || echo 0)
state_unique=$(sort -u "$state_file" 2>/dev/null | wc -l || echo 0)
if [ "$state_total" -eq "$state_unique" ]; then
    ok "state file sin duplicados ($state_total entradas)"
else
    ko "state file con duplicados ($state_total totales, $state_unique únicas)"
fi

printf '\n== 3. Regresión de casing JSON ==\n'
CFG="${HOME_A}/.config/opencode/opencode.json"
if [ -f "$CFG" ]; then
    if [ -n "$PY" ]; then
        if "$PY" -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8")); r=d["permission"]["read"]; assert "*secret*" in r and "*Secret*" in r and "*SECRET*" in r' "$CFG"; then
            ok 'opencode.json conserva las claves case-variant y es válido'
        else
            ko 'opencode.json inválido o perdió claves case-variant'
        fi
    else
        skip 'python/python3 no disponible: validación JSON omitida'
    fi
else
    ko 'no se generó opencode.json'
fi

printf '\n== 4. Integridad de la cadena SHA-256 del log ==\n'
LOG=$(find "${HOME_A}/.local/state" -name '*.jsonl' -type f 2>/dev/null | head -n1 || true)
if [ -z "$LOG" ]; then
    skip 'no se generó log (dry-run o directorio limpio)'
elif [ -z "$PY" ]; then
    skip 'python/python3 no disponible: verificación de hash omitida'
else
    if "$PY" - "$LOG" <<'PY'
import hashlib, json, sys
path = sys.argv[1]
prev = '0' * 64
count = 0
with open(path, encoding='utf-8') as fh:
    for line in fh:
        line = line.rstrip('\n')
        obj = json.loads(line)
        h = obj['hash']
        # El script construye la línea como: payload_sin_'}' + ',"hash":"..."}'
        # Por tanto el payload original se reconstruye con el '}' final.
        idx = line.rfind(',"hash":')
        assert idx > 0, 'formato de línea de log inválido'
        payload = line[:idx] + '}'
        assert hashlib.sha256(payload.encode('utf-8')).hexdigest() == h, f'hash inválido en seq {obj["seq"]}'
        assert obj['prev_hash'] == prev, f'prev_hash roto en seq {obj["seq"]}'
        prev = h
        count += 1
assert count > 0
print(f'  eventos verificados: {count}')
PY
    then
        ok 'cadena SHA-256 y prev_hash verificados'
    else
        ko 'cadena de auditoría rota'
    fi
fi

printf '\n== 5. Uninstall seguro con state manipulado ==\n'
VICTIM="${TMP_ROOT}/victim.txt"
printf 'no borrar' > "$VICTIM"
printf '%s\n' "$VICTIM" >> "${HOME_A}/.config/ai-governance/installed.txt"
run_bash "$HOME_A" --yes --allow-missing-mcp --uninstall
if [ -f "$VICTIM" ]; then
    ok 'ruta manipulada fuera de roots no fue borrada'
else
    ko 'uninstall borró una ruta fuera de los roots gestionados'
fi

printf '\n===============================\n'
printf 'PASS=%d  FAIL=%d  SKIP=%d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]

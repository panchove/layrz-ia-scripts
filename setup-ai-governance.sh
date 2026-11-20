#!/usr/bin/env bash
#
# setup-ai-governance.sh
# Despliega el marco completo de Gobernanza de IA e Ingeniería de Software
# (25 Pilares + Commit y PR Workflows) para OpenCode, Google Antigravity
# y Claude Code.
#
# Version : 2.3.2
# License : MIT
#
# Changelog:
#   2.3.2 - Supply chain y contrato:
#           * AI-BOM fijado en config/ai-mcp.lock (version + SHA-256 del MCP)
#           * $schema apunta al contrato vendorizado schemas/opencode-config-v1.json
#   2.3.1 - MCP resolution:
#           * Detecta el binario en ${USER_HOME}/AppData/Local/Programs/
#             (ruta real del instalador de Windows) sin hardcodear el usuario
#   2.3.0 - Governance hardening:
#           * Fuente única de contenido en content/ (elimina duplicación y drift)
#           * Log JSONL con correlation_id y cadena SHA-256 (prev_hash)
#           * Gate humano obligatorio antes de escribir (--yes para CI)
#           * Validación estricta de variables de entorno inyectadas en prompts
#           * Fail-fast del binario MCP (--allow-missing-mcp para omitir)
#           * Rollback compensatorio multi-target y kill switch por centinela
#           * umask 077 y enmascaramiento del home en logs
#   2.2.3 - Parity:
#           * Alineación de versión con el port de PowerShell 2.2.3
#           * validate_json (jq/python3) ya es case-sensitive; sin cambios funcionales en bash
#   2.2.2 - Hardening & Parity:
#           * Fallback seguro para USER_HOME (getent passwd / USERPROFILE)
#           * Rechaza --targets vacío o solo comas
#           * Normalización de rutas (realpath/readlink) en is_under_managed_roots

set -euo pipefail

# ------------------------------------------------------------------------------
# SHELL COMPATIBILITY
# ------------------------------------------------------------------------------
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: este script requiere bash (no 'sh')." >&2
    echo "       Ejecuta: bash $0 $*" >&2
    exit 1
fi
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "ERROR: se requiere bash >= 4 (detectado: $BASH_VERSION)" >&2
    exit 1
fi

# Pilar 18: permisos restrictivos para logs y backups.
umask 077

# ------------------------------------------------------------------------------
# DEFAULTS
# ------------------------------------------------------------------------------
DRY_RUN=false
FORCE=false
NO_BACKUP=false
UNINSTALL=false
YES=false
ALLOW_MISSING_MCP=false
TARGETS="opencode,gemini,claude"

# ------------------------------------------------------------------------------
# USAGE
# ------------------------------------------------------------------------------
usage() {
    cat <<EOF
${SCRIPT_NAME} v${SCRIPT_VERSION}

Despliega el marco de Gobernanza de IA (25 pilares + workflows) para
OpenCode, Google Antigravity (Gemini) y Claude Code.

USO:
    ${SCRIPT_NAME} [OPCIONES]

OPCIONES:
    -n, --dry-run           Muestra lo que haría sin modificar nada
    -f, --force             Sobrescribe archivos sin marker de este script
        --no-backup         No crea backups .bak.TIMESTAMP
        --uninstall         Elimina los archivos creados por este script
        --targets=LIST      Lista CSV: opencode,gemini,claude | all
                            (default: opencode,gemini,claude)
    -y, --yes               Acepta el gate humano (solo para CI controlado)
        --allow-missing-mcp Permite desplegar aunque falte el binario MCP
    -h, --help              Muestra esta ayuda
    -V, --version           Imprime la versión

VARIABLES DE ENTORNO:
    AI_AGENT_NAME_OPENCODE    Trailer Co-Authored-By para OpenCode
                              (default: "OpenCode <noreply@opencode.ai>")
    AI_AGENT_NAME_GEMINI      Trailer Co-Authored-By para Gemini/Antigravity
                              (default: "Gemini <noreply@google.com>")
    AI_AGENT_NAME_CLAUDE      Trailer Co-Authored-By para Claude Code
                              (default: "Claude Code <noreply@anthropic.com>")
    AI_AGENT_DISPLAY_*        Display en footer de PR
    AI_MCP_VERSION            Versión fijada del servidor MCP (AI-BOM)
    AI_MCP_SHA256             Hash SHA-256 esperado del binario MCP

EJEMPLOS:
    ${SCRIPT_NAME} --dry-run
    ${SCRIPT_NAME} --targets=opencode
    ${SCRIPT_NAME} --yes --targets=claude
    ${SCRIPT_NAME} --uninstall --dry-run

EOF
}

readonly SCRIPT_VERSION="2.3.2"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONTENT_DIR="${SCRIPT_DIR}/content"
readonly SCHEMA_V1="${SCRIPT_DIR}/schemas/opencode-config-v1.json"
readonly MCP_LOCK="${SCRIPT_DIR}/config/ai-mcp.lock"

# ------------------------------------------------------------------------------
# ARGUMENT PARSING
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)         DRY_RUN=true; shift ;;
        -f|--force)           FORCE=true; shift ;;
        --no-backup)          NO_BACKUP=true; shift ;;
        --uninstall)          UNINSTALL=true; shift ;;
        -y|--yes)             YES=true; shift ;;
        --allow-missing-mcp)  ALLOW_MISSING_MCP=true; shift ;;
        --targets=*)          TARGETS="${1#*=}"; shift ;;
        -h|--help)            usage; exit 0 ;;
        -V|--version)         echo "${SCRIPT_VERSION}"; exit 0 ;;
        --)                   shift; break ;;
        -*)                   echo "Opción desconocida: $1" >&2; usage >&2; exit 2 ;;
        *)                    echo "Argumento inesperado: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ "$TARGETS" = "all" ]; then
    TARGETS="opencode,gemini,claude"
fi

TARGET_LIST=()
IFS=',' read -ra _RAW_TARGETS <<< "$TARGETS"
for _t in "${_RAW_TARGETS[@]}"; do
    _t="${_t//[[:space:]]/}"
    [ -z "$_t" ] && continue
    case "$_t" in
        opencode|gemini|claude) TARGET_LIST+=("$_t") ;;
        *) echo "Target inválido: '$_t' (permitidos: opencode, gemini, claude, all)" >&2; exit 2 ;;
    esac
done

if [ "${#TARGET_LIST[@]}" -eq 0 ]; then
    echo "Targets vacío (permitidos: opencode, gemini, claude, all)" >&2
    exit 2
fi

target_enabled() {
    local t
    for t in "${TARGET_LIST[@]}"; do
        [ "$t" = "$1" ] && return 0
    done
    return 1
}

# ------------------------------------------------------------------------------
# HOME, PATHS Y LOGGING ESTRUCTURADO (Pilares 6 y 20)
# ------------------------------------------------------------------------------
resolve_user_home() {
    if [ -n "${HOME:-}" ]; then
        printf '%s' "$HOME"
        return 0
    fi
    if command -v getent >/dev/null 2>&1; then
        local _h
        _h=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6 || true)
        if [ -n "$_h" ]; then
            printf '%s' "$_h"
            return 0
        fi
    fi
    if [ -n "${USERPROFILE:-}" ]; then
        printf '%s' "$USERPROFILE"
        return 0
    fi
    echo "ERROR: no se pudo determinar el directorio HOME del usuario." >&2
    exit 1
}

readonly USER_HOME="$(resolve_user_home)"

readonly LOG_DIR="${USER_HOME}/.local/state"
if ! $DRY_RUN; then
    mkdir -p "$LOG_DIR"
fi
readonly LOG_FILE="${LOG_DIR}/ai-governance-setup.$(date +%Y%m%d-%H%M%S).$$.jsonl"
readonly CORRELATION_ID="$(date +%Y%m%d%H%M%S)-$$-${RANDOM}${RANDOM}"
LOG_SEQ=0
PREV_HASH="0000000000000000000000000000000000000000000000000000000000000000"

readonly OPENCODE_ROOT="${USER_HOME}/.config/opencode"
readonly OPENCODE_DOCS="${OPENCODE_ROOT}/docs"
readonly OPENCODE_COMMANDS="${OPENCODE_ROOT}/commands"
readonly GEMINI_ROOT="${USER_HOME}/.gemini"
readonly GEMINI_DOCS="${GEMINI_ROOT}/docs"
readonly ANTIGRAVITY_ROOT="${GEMINI_ROOT}/antigravity"
readonly ANTIGRAVITY_WORKFLOWS="${ANTIGRAVITY_ROOT}/global_workflows"
readonly CLAUDE_ROOT="${USER_HOME}/.claude"
readonly CLAUDE_DOCS="${CLAUDE_ROOT}/docs"
readonly GOV_PATH_OPENCODE="${OPENCODE_DOCS}/AI_GOVERNANCE.md"
readonly GOV_PATH_GEMINI="${GEMINI_DOCS}/AI_GOVERNANCE.md"
readonly GOV_PATH_CLAUDE="${CLAUDE_DOCS}/AI_GOVERNANCE.md"
readonly STATE_DIR="${USER_HOME}/.config/ai-governance"
readonly STATE_FILE="${STATE_DIR}/installed.txt"
readonly ABORT_FILE="${STATE_DIR}/ABORT"

sha256_of() {
    local data="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$data" | sha256sum | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        printf '%s' "$data" | shasum -a 256 | cut -d' ' -f1
    elif command -v openssl >/dev/null 2>&1; then
        printf '%s' "$data" | openssl dgst -sha256 | awk '{print $NF}'
    elif command -v python3 >/dev/null 2>&1; then
        printf '%s' "$data" | python3 -c 'import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'
    elif command -v python >/dev/null 2>&1; then
        printf '%s' "$data" | python -c 'import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'
    else
        echo "ERROR: se requiere un proveedor SHA-256 (sha256sum, shasum, openssl o python)" >&2
        return 1
    fi
}

sha256_file() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | cut -d' ' -f1
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file" | awk '{print $NF}'
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$file"
    elif command -v python >/dev/null 2>&1; then
        python -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$file"
    else
        echo "ERROR: se requiere un proveedor SHA-256" >&2
        return 1
    fi
}

json_escape() {
    local s="$1"
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$s" | jq -Rs .
    elif command -v python3 >/dev/null 2>&1; then
        printf '%s' "$s" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
    elif command -v python >/dev/null 2>&1; then
        printf '%s' "$s" | python -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
    else
        s=${s//\\/\\\\}; s=${s//\"/\\\"}
        s=${s//$'\t'/\\t}; s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}
        printf '"%s"\n' "$s"
    fi
}

log_event() {
    local level="$1"; shift
    local message="$*"
    # Pilar 24: enmascarar la ruta personal antes de escribir en el log.
    message="${message//$USER_HOME/<HOME>}"
    LOG_SEQ=$((LOG_SEQ + 1))
    local ts; ts=$(date '+%Y-%m-%dT%H:%M:%S%z')
    local payload
    payload=$(printf '{"ts":%s,"level":%s,"message":%s,"correlation_id":%s,"seq":%d,"prev_hash":"%s"' \
        "$(json_escape "$ts")" "$(json_escape "$level")" "$(json_escape "$message")" \
        "$(json_escape "$CORRELATION_ID")" "$LOG_SEQ" "$PREV_HASH")
    # El payload hasheado incluye el '}' final, igual que la reconstrucción que
    # hace el verificador a partir de la línea del log (payload + '}').
    local hash; hash=$(sha256_of "${payload}}") || return 1
    local line="${payload},\"hash\":\"${hash}\"}"
    if $DRY_RUN; then
        printf '%s\n' "$line" >&2
    else
        printf '%s\n' "$line" | tee -a "$LOG_FILE" >&2
    fi
    PREV_HASH="$hash"
}

log_info()  { log_event 'INFO'  "$*"; }
log_warn()  { log_event 'WARN'  "$*"; }
log_error() { log_event 'ERROR' "$*"; }
log_dry()   { log_event 'DRY'   "$*"; }

# Pilar 5: la divulgación debe ser el primer evento de la cadena, antes de
# cualquier advertencia emitida durante la resolución de dependencias.
log_event 'AI_DISCLOSURE' 'Asistido por IA (OpenCode); supervisión humana requerida'

# ------------------------------------------------------------------------------
# CONTENIDO (fuente única) Y VALIDACIÓN DE IDENTIDAD (Pilares 15, 11, 21)
# ------------------------------------------------------------------------------
readonly CONTENT_FILES=(AI_GOVERNANCE.md AGENTS.md.tmpl audit-governance.md commit.md.tmpl pr.md.tmpl)
for _f in "${CONTENT_FILES[@]}"; do
    if [ ! -f "${CONTENT_DIR}/${_f}" ]; then
        echo "ERROR: falta el archivo de contenido ${CONTENT_DIR}/${_f}" >&2
        exit 1
    fi
done
# Pilar 23: contrato de configuración versionado y AI-BOM fijado.
if [ ! -f "$SCHEMA_V1" ]; then
    echo "ERROR: falta el schema versionado $SCHEMA_V1" >&2
    exit 1
fi
if [ ! -f "$MCP_LOCK" ]; then
    echo "ERROR: falta el lockfile del MCP $MCP_LOCK" >&2
    exit 1
fi

AGENTS_TEMPLATE=$(cat "${CONTENT_DIR}/AGENTS.md.tmpl")
AUDIT_PROMPT=$(cat "${CONTENT_DIR}/audit-governance.md")
COMMIT_TEMPLATE=$(cat "${CONTENT_DIR}/commit.md.tmpl")
PR_TEMPLATE=$(cat "${CONTENT_DIR}/pr.md.tmpl")

validate_identity() {
    local value="$1" name="$2"
    if [ -z "$value" ] || [ "${#value}" -gt 120 ]; then
        log_error "Identidad inválida en ${name} (vacía o > 120 caracteres)"
        exit 2
    fi
    if ! printf '%s' "$value" | grep -Eq '^[A-Za-z0-9 <>.@_-]+$'; then
        log_error "Identidad inválida en ${name}: caracteres no permitidos"
        exit 2
    fi
}

readonly AI_AGENT_NAME_OPENCODE="${AI_AGENT_NAME_OPENCODE:-OpenCode <noreply@opencode.ai>}"
readonly AI_AGENT_NAME_GEMINI="${AI_AGENT_NAME_GEMINI:-Gemini <noreply@google.com>}"
readonly AI_AGENT_NAME_CLAUDE="${AI_AGENT_NAME_CLAUDE:-Claude Code <noreply@anthropic.com>}"
readonly AI_AGENT_DISPLAY_OPENCODE="${AI_AGENT_DISPLAY_OPENCODE:-OpenCode}"
readonly AI_AGENT_DISPLAY_GEMINI="${AI_AGENT_DISPLAY_GEMINI:-Gemini}"
readonly AI_AGENT_DISPLAY_CLAUDE="${AI_AGENT_DISPLAY_CLAUDE:-Claude Code}"

for _pair in \
    "OPENCODE:${AI_AGENT_NAME_OPENCODE}" "GEMINI:${AI_AGENT_NAME_GEMINI}" "CLAUDE:${AI_AGENT_NAME_CLAUDE}" \
    "OPENCODE:${AI_AGENT_DISPLAY_OPENCODE}" "GEMINI:${AI_AGENT_DISPLAY_GEMINI}" "CLAUDE:${AI_AGENT_DISPLAY_CLAUDE}"; do
    validate_identity "${_pair#*:}" "AI_AGENT_${_pair%%:*}"
done

apply_agent_subs() {
    local content="$1" name="$2" display="$3" gov="$4"
    content="${content//__GOV_PATH__/$gov}"
    content="${content//AI_AGENT_NAME_PLACEHOLDER/$name}"
    content="${content//__AI_AGENT_NAME__/$name}"
    content="${content//__AI_AGENT_DISPLAY__/$display}"
    if printf '%s' "$content" | grep -q '__GOV_PATH__\|__AI_AGENT_'; then
        log_error "Postcondición incumplida: quedaron placeholders sin sustituir"
        return 1
    fi
    printf '%s' "$content"
}

# ------------------------------------------------------------------------------
# MCP BINARY RESOLUTION (Pilar 10: fail-fast + hash opcional)
# ------------------------------------------------------------------------------
resolve_mcp_binary() {
    if command -v codebase-memory-mcp >/dev/null 2>&1; then
        command -v codebase-memory-mcp
        return 0
    fi
    local c
    for c in \
        "${USER_HOME}/.local/bin/codebase-memory-mcp" \
        "/usr/local/bin/codebase-memory-mcp" \
        "/opt/homebrew/bin/codebase-memory-mcp" \
        "${USER_HOME}/AppData/Local/Programs/codebase-memory-mcp/codebase-memory-mcp" \
        "${USER_HOME}/AppData/Local/Programs/codebase-memory-mcp/codebase-memory-mcp.exe"; do
        if [ -x "$c" ]; then
            printf '%s\n' "$c"
            return 0
        fi
    done
    return 1
}

MCP_BINARY_PATH=""
if ! MCP_BINARY_PATH=$(resolve_mcp_binary); then
    MCP_BINARY_PATH="${USER_HOME}/.local/bin/codebase-memory-mcp"
    if $ALLOW_MISSING_MCP; then
        log_warn "Binario MCP ausente; se despliega la config por --allow-missing-mcp"
    else
        log_error "Binario 'codebase-memory-mcp' no encontrado. Instálalo o usa --allow-missing-mcp"
        exit 1
    fi
fi

# El lockfile fija versión y hash por defecto; las variables de entorno lo
# sobrescriben para permitir actualizaciones controladas del componente.
MCP_VERSION="${AI_MCP_VERSION:-}"
MCP_SHA256="${AI_MCP_SHA256:-}"
if [ -z "$MCP_VERSION" ]; then
    MCP_VERSION=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MCP_LOCK" | head -n1)
fi
if [ -z "$MCP_SHA256" ]; then
    MCP_SHA256=$(sed -n 's/.*"sha256"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MCP_LOCK" | head -n1)
fi

if [ -n "$MCP_SHA256" ]; then
    if [ -f "$MCP_BINARY_PATH" ]; then
        actual=$(sha256_file "$MCP_BINARY_PATH") || exit 1
        if [ "$actual" != "$MCP_SHA256" ]; then
            log_error "Hash del MCP no coincide (AI-BOM): esperado ${MCP_SHA256}, obtenido ${actual}"
            exit 1
        fi
        log_info "MCP v${MCP_VERSION:-sin versión} verificado por SHA-256 (AI-BOM lock)"
    elif $ALLOW_MISSING_MCP; then
        log_warn "MCP ausente: no se pudo verificar el hash fijado ${MCP_SHA256}"
    else
        log_error "No se puede verificar el hash del MCP: binario inexistente"
        exit 1
    fi
elif [ -n "$MCP_VERSION" ]; then
    log_warn "MCP versión ${MCP_VERSION} declarada sin hash; AI-BOM incompleto"
fi

# ------------------------------------------------------------------------------
# HELPERS DE ESTADO Y ESCRITURA (Pilares 16, 19)
# ------------------------------------------------------------------------------
is_managed() {
    [ -f "$STATE_FILE" ] && grep -Fxq "$1" "$STATE_FILE"
}

record_managed() {
    local path="$1"
    $DRY_RUN && return 0
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
    grep -Fxq "$path" "$STATE_FILE" 2>/dev/null || printf '%s\n' "$path" >> "$STATE_FILE"
}

unrecord_managed() {
    local path="$1" tmp
    [ -f "$STATE_FILE" ] || return 0
    tmp=$(mktemp)
    grep -Fxv "$path" "$STATE_FILE" > "$tmp" || true
    mv "$tmp" "$STATE_FILE"
}

assert_under_managed_roots() {
    local p="$1" r
    for r in "$OPENCODE_ROOT" "$GEMINI_ROOT" "$CLAUDE_ROOT"; do
        case "$p" in "$r"/*) return 0 ;; esac
    done
    log_error "Precondición incumplida: ruta fuera de los roots gestionados: $p"
    return 1
}

# Manifiesto para rollback compensatorio (backup<TAB>destino).
ROLLBACK_MANIFEST=""
init_rollback() {
    if ! $DRY_RUN; then
        ROLLBACK_MANIFEST=$(mktemp "${TMPDIR:-/tmp}/ai-governance-rollback.XXXXXX")
        : > "$ROLLBACK_MANIFEST"
    fi
}

rollback_deployed() {
    [ -n "$ROLLBACK_MANIFEST" ] || return 0
    while IFS=$'\t' read -r backup path; do
        [ -n "${path:-}" ] || continue
        if [ "$backup" != "-" ] && [ -f "$backup" ]; then
            mv -f "$backup" "$path"
        else
            rm -f "$path"
        fi
        unrecord_managed "$path"
        log_warn "Rollback aplicado: $path"
    done < "$ROLLBACK_MANIFEST"
    rm -f "$ROLLBACK_MANIFEST"
    ROLLBACK_MANIFEST=""
}

write_file() {
    local path="$1" content="$2"
    local dir; dir=$(dirname "$path")

    # Precondiciones (DbC).
    [ -n "$path" ] || { log_error "Precondición incumplida: path vacío"; return 1; }
    [ -n "$content" ] || { log_error "Precondición incumplida: contenido vacío para $path"; return 1; }
    assert_under_managed_roots "$path" || return 1
    check_abort || return 1

    if $DRY_RUN; then
        log_dry "Escribiría $(printf '%s' "$content" | wc -c | tr -d ' ') bytes -> $path"
        return 0
    fi

    mkdir -p "$dir"
    if [ -f "$path" ] && ! is_managed "$path" && ! $FORCE; then
        log_error "Rechazo sobrescribir archivo ajeno (sin marker): $path"
        return 1
    fi

    local backup="-"
    if [ -f "$path" ] && ! $NO_BACKUP; then
        backup="${path}.bak.$(date +%Y%m%d%H%M%S).$$"
        if cp -p "$path" "$backup"; then
            printf '%s\t%s\n' "$backup" "$path" >> "$ROLLBACK_MANIFEST"
            log_info "Backup: $backup"
        else
            backup="-"
            log_warn "No se pudo crear backup de $path"
        fi
    else
        printf '%s\t%s\n' "-" "$path" >> "$ROLLBACK_MANIFEST"
    fi

    local tmp
    tmp=$(mktemp "${dir}/.$(basename "$path").tmp.XXXXXX")
    printf '%s\n' "$content" > "$tmp"
    if ! mv "$tmp" "$path"; then
        rm -f "$tmp"
        log_error "Fallo al mover $tmp -> $path"
        return 1
    fi

    # Postcondición (DbC).
    if [ ! -s "$path" ]; then
        log_error "Postcondición incumplida: $path no existe o está vacío"
        return 1
    fi
    log_info "Escrito: $path"
    record_managed "$path"
}

check_abort() {
    if [ -e "$ABORT_FILE" ]; then
        log_error "Kill switch activo ($ABORT_FILE); abortando despliegue"
        return 1
    fi
    return 0
}

validate_json() {
    local file="$1"
    [ -f "$file" ] || { log_warn "JSON no encontrado: $file"; return 1; }
    if command -v jq >/dev/null 2>&1; then
        if jq -e . "$file" >/dev/null 2>&1; then
            log_info "JSON OK: $file"
            return 0
        fi
        log_error "JSON INVÁLIDO: $file"
        return 1
    elif command -v python3 >/dev/null 2>&1; then
        if python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$file" >/dev/null 2>&1; then
            log_info "JSON OK (python3): $file"
            return 0
        fi
        log_error "JSON INVÁLIDO: $file"
        return 1
    elif command -v python >/dev/null 2>&1; then
        if python -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$file" >/dev/null 2>&1; then
            log_info "JSON OK (python): $file"
            return 0
        fi
        log_error "JSON INVÁLIDO: $file"
        return 1
    fi
    log_warn "jq/python ausentes: se omite la validación de $file"
    return 0
}

# ------------------------------------------------------------------------------
# GATE HUMANO (Pilar 4)
# ------------------------------------------------------------------------------
require_human_gate() {
    if $DRY_RUN; then return 0; fi
    if $YES; then
        log_event 'APPROVAL' "Aprobación declarada mediante --yes"
        return 0
    fi
    if [ -t 0 ]; then
        printf 'Va a desplegar gobernanza en: %s. ¿Continuar? [s/N]: ' "$TARGETS" >&2
        local answer=""; read -r answer || answer=""
        case "$answer" in
            s|S|si|SI|Si|y|Y)
                log_event 'APPROVAL' "Aprobación interactiva confirmada" ;;
            *)
                log_event 'ABORT' "Gate humano rechazado"
                exit 3 ;;
        esac
    else
        log_error "Se requiere confirmación humana: usa --yes en sesiones no interactivas"
        exit 3
    fi
}

# ------------------------------------------------------------------------------
# UNINSTALL
# ------------------------------------------------------------------------------
normalize_path() {
    local p="$1"
    if command -v realpath >/dev/null 2>&1 && realpath -m "$p" >/dev/null 2>&1; then
        realpath -m "$p"
    elif command -v readlink >/dev/null 2>&1 && readlink -f "$p" >/dev/null 2>&1; then
        readlink -f "$p"
    else
        printf '%s' "$p"
    fi
}

is_under_managed_roots() {
    local target_norm r r_norm
    target_norm=$(normalize_path "$1")
    for r in "$OPENCODE_ROOT" "$GEMINI_ROOT" "$CLAUDE_ROOT"; do
        r_norm=$(normalize_path "$r")
        case "$target_norm" in "$r_norm"/*) return 0 ;; esac
    done
    return 1
}

do_uninstall() {
    if [ ! -f "$STATE_FILE" ]; then
        log_warn "Sin state file en $STATE_FILE; nada que desinstalar."
        return 0
    fi
    log_info "Desinstalando archivos registrados en $STATE_FILE"
    local path
    while IFS= read -r path; do
        [ -z "$path" ] && continue
        if ! is_under_managed_roots "$path"; then
            log_warn "Ruta fuera de los roots gestionados; se omite: $path"
            continue
        fi
        if [ ! -e "$path" ] && [ ! -L "$path" ]; then
            log_warn "No existe (¿ya eliminado?): $path"
            continue
        fi
        if $DRY_RUN; then
            log_dry "Eliminaría: $path"
        else
            rm -f "$path" && log_info "Eliminado: $path"
        fi
    done < "$STATE_FILE"

    local dirs=(
        "$OPENCODE_COMMANDS" "$OPENCODE_DOCS" "$OPENCODE_ROOT"
        "$ANTIGRAVITY_WORKFLOWS" "$ANTIGRAVITY_ROOT" "$GEMINI_DOCS" "$GEMINI_ROOT"
        "$CLAUDE_DOCS" "$CLAUDE_ROOT"
    )
    local d
    for d in "${dirs[@]}"; do
        [ -d "$d" ] || continue
        if $DRY_RUN; then
            log_dry "Intentaría rmdir (solo si vacío): $d"
        else
            rmdir "$d" 2>/dev/null && log_info "Directorio vacío eliminado: $d" || true
        fi
    done

    if ! $DRY_RUN; then
        rm -f "$STATE_FILE"
        log_info "State file eliminado"
        rmdir "$STATE_DIR" 2>/dev/null || true
    fi
    log_info "Desinstalación completa."
}

# ------------------------------------------------------------------------------
# DEPLOY PER TARGET
# ------------------------------------------------------------------------------
write_json_configs() {
    local mcp_json agents_md_json gov_md_json schema_json
    mcp_json=$(json_escape "$MCP_BINARY_PATH")
    agents_md_json=$(json_escape "${OPENCODE_ROOT}/AGENTS.md")
    gov_md_json=$(json_escape "$GOV_PATH_OPENCODE")
    # Pilar 23: se fija el contrato al schema v1 vendorizado en el repositorio.
    schema_json=$(json_escape "$SCHEMA_V1")

    local cfg
    cfg=$(cat <<EOF
{
  "\$schema": $schema_json,
  "instructions": [
    $agents_md_json,
    $gov_md_json
  ],
  "share": "disabled",
  "autoupdate": false,
  "mcp": {
    "codebase-memory-mcp": {
      "enabled": true,
      "type": "local",
      "command": [
        $mcp_json
      ]
    }
  },
  "permission": {
    "read": {
      "*": "allow",
      "*.env": "ask",
      "*.env.*": "ask",
      "*secret*": "ask",
      "*Secret*": "ask",
      "*SECRET*": "ask",
      "*token*": "ask",
      "*credential*": "ask",
      "*Credential*": "ask",
      "*.pem": "deny",
      "*.key": "deny",
      "*.pfx": "deny",
      "*.p12": "deny"
    },
    "edit": "ask",
    "webfetch": "ask",
    "bash": {
      "*": "ask",
      "git status": "allow",
      "git status *": "allow",
      "git diff *": "allow",
      "git log *": "allow",
      "git branch": "allow",
      "git branch *": "allow",
      "git fetch *": "allow",
      "git add *": "allow",
      "git commit *": "allow",
      "git push": "allow",
      "git push -u origin *": "allow",
      "gh pr *": "allow",
      "gh repo view *": "allow",
      "gh auth status": "allow",
      "ls *": "allow",
      "dir *": "allow",
      "Get-ChildItem *": "allow",
      "find *": "allow",
      "pytest *": "allow",
      "go test *": "allow",
      "dotnet test *": "allow",
      "npm test *": "allow",
      "bash tests/*": "allow",
      "rm -rf *": "deny",
      "rm -fr *": "deny",
      "rm -Rf *": "deny",
      "rm -rF *": "deny",
      "rm --recursive *": "deny",
      "Remove-Item * -Recurse *": "deny",
      "git push --force *": "deny",
      "git push -f *": "deny",
      "git reset --hard *": "deny",
      "git clean -fdx *": "deny",
      "gh auth token*": "deny",
      "gh repo delete*": "deny",
      "gh secret *": "deny",
      "gh ssh-key *": "deny",
      "gh gpg-key *": "deny",
      "curl *": "ask",
      "wget *": "ask",
      "Invoke-WebRequest *": "ask",
      "Invoke-RestMethod *": "ask",
      "docker rm *": "deny",
      "docker rmi *": "deny",
      "docker container rm *": "deny",
      "docker volume rm *": "deny",
      "docker system prune *": "deny"
    }
  }
}
EOF
)
    write_file "$OPENCODE_ROOT/opencode.json" "$cfg"
}

deploy_opencode() {
    log_info "=== Target: OpenCode ==="
    write_file "$GOV_PATH_OPENCODE" "$(cat "${CONTENT_DIR}/AI_GOVERNANCE.md")"
    write_file "$OPENCODE_ROOT/AGENTS.md" \
        "$(apply_agent_subs "$AGENTS_TEMPLATE" "$AI_AGENT_NAME_OPENCODE" "$AI_AGENT_DISPLAY_OPENCODE" "$GOV_PATH_OPENCODE")"
    write_file "$OPENCODE_COMMANDS/audit-governance.md" "$AUDIT_PROMPT"
    write_file "$OPENCODE_COMMANDS/commit.md" \
        "$(apply_agent_subs "$COMMIT_TEMPLATE" "$AI_AGENT_NAME_OPENCODE" "$AI_AGENT_DISPLAY_OPENCODE" "$GOV_PATH_OPENCODE")"
    write_file "$OPENCODE_COMMANDS/pr.md" \
        "$(apply_agent_subs "$PR_TEMPLATE" "$AI_AGENT_NAME_OPENCODE" "$AI_AGENT_DISPLAY_OPENCODE" "$GOV_PATH_OPENCODE")"
    write_json_configs
}

deploy_gemini() {
    log_info "=== Target: Gemini / Antigravity ==="
    write_file "$GOV_PATH_GEMINI" "$(cat "${CONTENT_DIR}/AI_GOVERNANCE.md")"
    write_file "$GEMINI_ROOT/GEMINI.md" \
        "$(apply_agent_subs "$AGENTS_TEMPLATE" "$AI_AGENT_NAME_GEMINI" "$AI_AGENT_DISPLAY_GEMINI" "$GOV_PATH_GEMINI")"
    write_file "$ANTIGRAVITY_WORKFLOWS/audit-governance.md" "$AUDIT_PROMPT"
    write_file "$ANTIGRAVITY_WORKFLOWS/commit.md" \
        "$(apply_agent_subs "$COMMIT_TEMPLATE" "$AI_AGENT_NAME_GEMINI" "$AI_AGENT_DISPLAY_GEMINI" "$GOV_PATH_GEMINI")"
    write_file "$ANTIGRAVITY_WORKFLOWS/pr.md" \
        "$(apply_agent_subs "$PR_TEMPLATE" "$AI_AGENT_NAME_GEMINI" "$AI_AGENT_DISPLAY_GEMINI" "$GOV_PATH_GEMINI")"
    local mcp_json
    mcp_json=$(json_escape "$MCP_BINARY_PATH")
    local cfg
    cfg=$(cat <<EOF
{
  "mcpServers": {
    "codebase-memory-mcp": {
      "command": $mcp_json,
      "args": []
    }
  }
}
EOF
)
    write_file "$ANTIGRAVITY_ROOT/mcp_config.json" "$cfg"
}

deploy_claude() {
    log_info "=== Target: Claude Code ==="
    write_file "$GOV_PATH_CLAUDE" "$(cat "${CONTENT_DIR}/AI_GOVERNANCE.md")"
    write_file "$CLAUDE_ROOT/CLAUDE.md" \
        "$(apply_agent_subs "$AGENTS_TEMPLATE" "$AI_AGENT_NAME_CLAUDE" "$AI_AGENT_DISPLAY_CLAUDE" "$GOV_PATH_CLAUDE")"
}

# ------------------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------------------
main() {
    log_info "setup-ai-governance.sh v${SCRIPT_VERSION}"
    log_info "Correlation ID: ${CORRELATION_ID}"
    log_info "HOME: <HOME>"
    log_info "Targets: $TARGETS"
    log_info "MCP binary: $MCP_BINARY_PATH"
    log_info "Dry-run: $DRY_RUN  Force: $FORCE  No-backup: $NO_BACKUP  Uninstall: $UNINSTALL  Yes: $YES"
    log_info "Log: $LOG_FILE"

    if $UNINSTALL; then
        do_uninstall
        return 0
    fi

    require_human_gate
    init_rollback

    if target_enabled opencode; then
        check_abort || { rollback_deployed; return 1; }
        deploy_opencode || { rollback_deployed; return 1; }
    fi
    if target_enabled gemini; then
        check_abort || { rollback_deployed; return 1; }
        deploy_gemini || { rollback_deployed; return 1; }
    fi
    if target_enabled claude; then
        check_abort || { rollback_deployed; return 1; }
        deploy_claude || { rollback_deployed; return 1; }
    fi

    if ! $DRY_RUN; then
        local ok=true
        target_enabled opencode && { validate_json "$OPENCODE_ROOT/opencode.json" || ok=false; }
        target_enabled gemini   && { validate_json "$ANTIGRAVITY_ROOT/mcp_config.json" || ok=false; }
        if $ok; then
            log_info "Validación final: OK"
            rm -f "$ROLLBACK_MANIFEST"
            ROLLBACK_MANIFEST=""
        else
            log_error "Validación final: FALLÓ (revisa el log)"
            rollback_deployed
            return 1
        fi
    fi

    cat <<EOF

🎉 [COMPLETADO] Marco de Gobernanza de IA v${SCRIPT_VERSION} desplegado.

📂 Rutas:
   - OpenCode:           ${OPENCODE_ROOT}
   - Gemini/Antigravity: ${GEMINI_ROOT}
   - Claude Code:        ${CLAUDE_ROOT}

📋 State:  ${STATE_FILE}
📋 Log:    ${LOG_FILE}

💡 Reinicia tu terminal/editor para que los agentes carguen las nuevas reglas.
   Desinstalar:  ${SCRIPT_NAME} --uninstall
   Simular:      ${SCRIPT_NAME} --dry-run
EOF
    return 0
}

if ! main "$@"; then
    exit 1
fi
exit 0

# AGENTS.md — layrz-ia-scripts

Este repositorio contiene **dos scripts ports fieles (versión 2.3.2)**, una fuente única de contenido, documentación de gobernanza y una suite de pruebas:

- `setup-ai-governance.sh` (bash, ejecutable) — requiere **bash >= 4** (no `sh`).
- `setup-ai-governance.ps1` (PowerShell 5.1+).
- `content/` — plantillas Markdown canónicas (única fuente de verdad).
- `tests/run_tests.sh` — suite de paridad, idempotencia, uninstall seguro, casing y cadena SHA-256.
- `docs/` — política, riesgo, impacto, arquitectura, ADRs y perfil de aplicabilidad.

Despliegan el marco de Gobernanza de IA (25 pilares) en raíces de configuración de agentes **fuera de este repositorio**:
- `~/.config/opencode` → OpenCode (`AGENTS.md`, `opencode.json`, `commands/`)
- `~/.gemini` / `~/.gemini/antigravity/global_workflows` → Gemini / Antigravity (`GEMINI.md`, flujos)
- `~/.claude` → Claude Code (`CLAUDE.md`)

## Comandos

| Comando | Qué hace |
|---|---|
| `bash setup-ai-governance.sh` | Despliega en los 3 targets (pide confirmación humana) |
| `bash setup-ai-governance.sh --dry-run` | Simula sin modificar nada (usa antes de cualquier cambio) |
| `bash setup-ai-governance.sh --yes` | Acepta el gate humano; solo para CI controlado |
| `bash setup-ai-governance.sh --allow-missing-mcp` | Despliega aunque falte `codebase-memory-mcp` |
| `bash setup-ai-governance.sh --targets=opencode` | Solo un target (opencode, gemini, claude, all) |
| `bash setup-ai-governance.sh --force` | Sobrescribe archivos sin marker de este script |
| `bash setup-ai-governance.sh --no-backup` | No crea backups `.bak.<timestamp>.<PID>` |
| `bash setup-ai-governance.sh --uninstall` | Borra los archivos registrados en el state file |
| `./setup-ai-governance.ps1` | Equivalente PowerShell (mismos flags: `-DryRun`, `-Yes`, `-AllowMissingMcp`, `-Force`, `-NoBackup`, `-Uninstall`, `-Targets`) |
| `bash tests/run_tests.sh` | Ejecuta la suite de verificaciones (requiere bash, python3 y opcionalmente pwsh) |

## Reglas que un agente probablemente pasaría por alto

1. **Los dos scripts son un par con fuente única.** El contenido literal vive en `content/`; está prohibido duplicar Markdown en los scripts. Cualquier cambio de flags, versión o contenido debe aplicarse **idénticamente** en `.sh` y `.ps1` y reflejarse en el changelog de ambos. Versión sincronizada actual: **2.3.2**.
2. **Escribe en `$HOME`, no en este repo.** Los destinos son `~/.config/opencode`, `~/.gemini`, `~/.claude`, `~/.config/ai-governance` y `~/.local/state`. No esperes artefactos de build ni salida aquí (salvo los logs de `tests/`).
3. **Sí hay tests.** Ejecuta `bash tests/run_tests.sh` tras cualquier cambio. La validación JSON final del script (`jq`/`python3` en bash; parser case-sensitive en PS) es solo una de las verificaciones.
4. **Gate humano obligatorio.** Sin `--dry-run`, el script pide confirmación interactiva; en sesiones no interactivas exige `--yes` / `-Yes`. Nunca lo bypases sin aprobación humana.
5. **State file:** `~/.config/ai-governance/installed.txt` registra los archivos gestionados para idempotencia y uninstall. No lo borres ni edites a mano.
6. **Backup y rollback:** al sobrescribir se crea `.bak.<timestamp>.<PID>` salvo `--no-backup`. Si falla un target, se aplica rollback compensatorio de los anteriores.
7. **Sin marker → sin sobrescribir:** el script rechaza sobrescribir archivos ajenos sin `--force`.
8. **MCP binario:** `codebase-memory-mcp` se resuelve desde `PATH`, `~/.local/bin`, `/usr/local/bin`, `/opt/homebrew/bin` y `~/AppData/Local/Programs/codebase-memory-mcp/` (sin hardcodear el usuario). Si falta, el script **falla en arranque** salvo `--allow-missing-mcp`. `AI_MCP_VERSION` y `AI_MCP_SHA256` fijan el AI-BOM.
9. **Logs JSONL con hash:** `~/.local/state/ai-governance-setup.*.jsonl` incluye `correlation_id`, `seq`, `prev_hash` y `hash` SHA-256; está encadenado. No lo edites.
10. **Kill switch:** la existencia de `~/.config/ai-governance/ABORT` detiene el despliegue antes de escribir.
11. **Variables de entorno:** `AI_AGENT_NAME_OPENCODE/GEMINI/CLAUDE` y `AI_AGENT_DISPLAY_OPENCODE/GEMINI/CLAUDE` controlan trailers y firmas; se validan con allowlist antes de interpolarse en prompts.
12. **AI-BOM y contrato fijados:** `config/ai-mcp.lock` fija versión/hash del MCP y `schemas/opencode-config-v1.json` fija el `$schema`. Para actualizar el MCP, cambia el lock (o usa `AI_MCP_VERSION`/`AI_MCP_SHA256`); para cambiar el contrato, crea `schemas/opencode-config-v2.json` y actualiza el path en ambos scripts.
13. **Changelog y docs:** ambas cabeceras incluyen changelog; actualízalo junto con `README.md` y `docs/` (Pilar 17). La reindexación de `codebase-memory-mcp` debe ejecutarse al finalizar.

## Qué NO hacer

- No uses `git add -A`; añade archivos explícitamente por nombre (repo público en `github.com/panchove/layrz-ia-scripts`).
- No agregues dependencias, lockfiles ni herramientas de build: los scripts siguen siendo autónomos y solo necesitan herramientas del sistema.
- No hardcodees rutas de usuario; usa `HOME`/`USERPROFILE` y `resolve_user_home()`.
- No des actos por válidos el gate humano, la cadena de hash ni la firma de PR.

## Referencia

- `content/AI_GOVERNANCE.md` (versión 2.2) se despliega en `~/.config/opencode/docs`, `~/.gemini/docs` y `~/.claude/docs` con contenido idéntico.
- `docs/APPLICABILITY.md` define qué pilares son N.A. en este repo.
- `docs/ARCHITECTURE.md` y `docs/adr/` contienen el modelo C4-lite y las decisiones.

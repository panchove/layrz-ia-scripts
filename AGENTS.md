# AGENTS.md — layrz-ia-scripts

Este repositorio tiene solo dos archivos, ambos versión 2.2.2 y ports fieles el uno del otro:

- `setup-ai-governance.sh` (bash, ejecutable) — requiere **bash >= 4** (no `sh`).
- `setup-ai-governance.ps1` (PowerShell 5.1+).

Despliegan el marco de Gobernanza de IA (25 pilares) en raíces de configuración de agentes **fuera de este repositorio**:
- `~/.config/opencode` → OpenCode (`AGENTS.md`, `opencode.json`, `commands/`)
- `~/.gemini` / `~/.gemini/antigravity/global_workflows` → Gemini / Antigravity (`GEMINI.md`, flujos)
- `~/.claude` → Claude Code (`CLAUDE.md`)

## Comandos

| Comando | Qué hace |
|---|---|
| `bash setup-ai-governance.sh` | Despliega en los 3 targets por defecto (opencode, gemini, claude) |
| `bash setup-ai-governance.sh --dry-run` | Solo muestra lo que haría, sin modificar nada (usa antes de cualquier cambio) |
| `bash setup-ai-governance.sh --targets=opencode` | Solo un target (válidos: opencode, gemini, claude, all) |
| `bash setup-ai-governance.sh --force` | Sobrescribe archivos sin marker de este script |
| `bash setup-ai-governance.sh --no-backup` | No crea backups `.bak.TIMESTAMP.PID` al sobrescribir |
| `bash setup-ai-governance.sh --uninstall` | Borra los archivos registrados en el state file |
| `./setup-ai-governance.ps1` | Equivalente PowerShell (mismos flags: `-DryRun`, `-Force`, `-NoBackup`, `-Uninstall`, `-Targets`) |

## Reglas que un agente probablemente pasaría por alto

1. **Los dos scripts son un par.** Cualquier cambio (flags, versión, changelog, contenido de `AGENTS.md`/`GEMINI.md`/`CLAUDE.md`/`opencode.json`) debe aplicarse **idénticamente** en `.sh` y `.ps1`. Mantén la versión sincronizada (actualmente 2.2.2) en ambas cabeceras y changelogs.
2. **Escribe en `$HOME`, no en este repo.** Los destinos son `~/.config/opencode`, `~/.gemini`, `~/.claude`, `~/.config/ai-governance` y `~/.local/state`. No esperes artefactos de build, tests ni salida en este directorio.
3. **No hay tests, lint, CI ni `package.json`.** No inventes comandos de verificación. El único chequeo ejecutable es la validación JSON final del script (`jq` o `python3`).
4. **State file:** `~/.config/ai-governance/installed.txt` registra los archivos gestionados para idempotencia y uninstall. No lo borres ni edites a mano.
5. **Backup:** al sobrescribir se crea `.bak.<timestamp>.<PID>` a menos que se use `--no-backup`.
6. **Sin marker → sin sobrescribir:** el script rechaza sobrescribir archivos ajenos sin `--force`.
7. **MCP binario:** `codebase-memory-mcp` se resuelve desde `PATH` o rutas típicas; si falta, la config se escribe igual con advertencia.
8. **Variables de entorno:** `AI_AGENT_NAME_OPENCODE/GEMINI/CLAUDE` y `AI_AGENT_DISPLAY_OPENCODE/GEMINI/CLAUDE` controlan los trailers `Co-Authored-By` y las firmas de PR desplegadas.
9. **Changelog:** ambas cabeceras incluyen un changelog; actualízalo al tocar cualquier script.

## Qué NO hacer

- No uses `git add -A` ni flujos de git para trabajar en este repo (no es un repositorio git).
- No agregues dependencias, lockfiles ni herramientas de build: el repo intencionalmente solo tiene dos scripts autónomos.
- No hardcodees rutas de usuario; usa `HOME`/`USERPROFILE` y `resolve_user_home()`.

## Referencia

- `docs/AI_GOVERNANCE.md` (versión 2.2) se despliega en `~/.config/opencode/docs`, `~/.gemini/docs` y `~/.claude/docs` con contenido idéntico.

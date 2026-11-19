# layrz-ia-scripts

Despliega el marco de Gobernanza de IA e Ingeniería de Software (25 pilares + workflows de commit/PR) para agentes de código: **OpenCode**, **Gemini / Google Antigravity** y **Claude Code**.

## Contenido

| Archivo | Qué es |
|---|---|
| `setup-ai-governance.sh` | Desplegador Bash (requiere **bash >= 4**, no `sh`) |
| `setup-ai-governance.ps1` | Port fiel a PowerShell; requiere **PowerShell 7.7** (en 5.1 falla la validación JSON) |
| `AGENTS.md` | Instrucciones para sesiones de OpenCode en este repo |

## Qué hace

Escribe configuración y documentación de gobernanza en las raíces de los agentes **fuera de este repositorio**:

- `~/.config/opencode` → OpenCode (`AGENTS.md`, `opencode.json`, `commands/`)
- `~/.gemini` / `~/.gemini/antigravity/global_workflows` → Gemini / Antigravity (`GEMINI.md`, flujos)
- `~/.claude` → Claude Code (`CLAUDE.md`)

Registra los archivos gestionados en `~/.config/ai-governance/installed.txt` para idempotencia y uninstall limpio.

## Uso rápido

```bash
# Ver qué haría sin tocar nada
bash setup-ai-governance.sh --dry-run

# Desplegar en los 3 targets por defecto
bash setup-ai-governance.sh

# Solo un target (opencode | gemini | claude | all)
bash setup-ai-governance.sh --targets=opencode

# Desinstalar lo gestionado por este script
bash setup-ai-governance.sh --uninstall
```

Equivalente en PowerShell (usa **PowerShell 7.7** / `pwsh`, no Windows PowerShell 5.1):

```powershell
pwsh -NoProfile -File ./setup-ai-governance.ps1 -DryRun
pwsh -NoProfile -File ./setup-ai-governance.ps1 -Targets opencode
pwsh -NoProfile -File ./setup-ai-governance.ps1 -Uninstall
```

## Opciones

| Opción | Efecto |
|---|---|
| `--dry-run` / `-DryRun` | Solo muestra lo que haría, sin modificar nada |
| `--force` / `-Force` | Sobrescribe archivos sin marker de este script |
| `--no-backup` / `-NoBackup` | No crea backups `.bak.TIMESTAMP.PID` |
| `--uninstall` / `-Uninstall` | Borra los archivos registrados en el state file |
| `--targets=` / `-Targets` | CSV de targets; válidos: opencode, gemini, claude, all |

## Variables de entorno

- `AI_AGENT_NAME_OPENCODE/GEMINI/CLAUDE` — trailer `Co-Authored-By` desplegado
- `AI_AGENT_DISPLAY_OPENCODE/GEMINI/CLAUDE` — firma de PR desplegada

## Notas importantes

- Los scripts escriben en `$HOME`, **no en este repositorio**. No esperes artefactos de build, tests ni salida aquí.
- No hay tests, lint, CI ni `package.json`. El único chequeo ejecutable es la validación JSON final (`jq` o `python3`).
- Al sobrescribir se crea backup `.bak.TIMESTAMP.PID` salvo que se use `--no-backup`.
- Sin marker en el state file, el script rechaza sobrescribir archivos ajenos salvo que uses `--force`.
- `setup-ai-governance.ps1` se ejecuta correctamente en **PowerShell 7.7** (verificado con `pwsh -NoProfile -File ./setup-ai-governance.ps1 -DryRun`).
- **No usar Windows PowerShell 5.1**: su `ConvertFrom-Json` maneja las claves del JSON como *case-insensitive* y, en un despliegue completo, la validación final falla con `... contiene las claves '*secret*' y '*Secret*' duplicadas` (igual ocurre con `*credential*` / `*Credential*` / `*SECRET*`). El `#Requires -Version 5.1` del script no garantiza que funcione en 5.1; usa siempre `pwsh` 7.7+.
- Los dos scripts son un par: cambios en uno deben reflejarse en el otro (versión, flags, changelog). Versión actual: **2.2.2**.

## Licencia

MIT — véase `LICENSE`.

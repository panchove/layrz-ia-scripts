# layrz-ia-scripts

Despliega el marco de Gobernanza de IA e Ingeniería de Software (25 pilares + workflows de commit/PR) para agentes de código: **OpenCode**, **Gemini / Google Antigravity** y **Claude Code**.

**Versión actual: 2.3.2.** El repositorio es un instalador determinista: no contiene modelos, agentes autónomos ni llamadas de red. La IA interviene solo como asistente de desarrollo y auditoría (ver `docs/AI_POLICY.md`).

## Contenido

| Archivo | Qué es |
|---|---|
| `setup-ai-governance.sh` | Desplegador Bash (requiere **bash >= 4**, no `sh`) |
| `setup-ai-governance.ps1` | Port fiel a PowerShell (PowerShell 5.1+; verificado en 5.1 y 7.7) |
| `content/` | **Fuente única** de las plantillas Markdown desplegadas |
| `schemas/opencode-config-v1.json` | Contrato de configuración OpenCode **versionado** (fijado en `$schema`) |
| `config/ai-mcp.lock` | AI-BOM: versión y SHA-256 fijados del servidor MCP |
| `tests/run_tests.sh` | Suite de paridad, idempotencia, uninstall, casing y cadena SHA-256 |
| `docs/` | Política de IA, riesgo, impacto, arquitectura, ADRs y perfil de aplicabilidad |
| `AGENTS.md` | Instrucciones para sesiones de IA en este repo |

> Los scripts **deben distribuirse junto con `content/`**: la unidad de distribución es el repositorio completo, no un archivo aislado.

## Qué hace

Escribe configuración y documentación de gobernanza en las raíces de los agentes **fuera de este repositorio**:

- `~/.config/opencode` → OpenCode (`AGENTS.md`, `opencode.json`, `commands/`)
- `~/.gemini` / `~/.gemini/antigravity/global_workflows` → Gemini / Antigravity (`GEMINI.md`, flujos)
- `~/.claude` → Claude Code (`CLAUDE.md`)

Registra los archivos gestionados en `~/.config/ai-governance/installed.txt` (idempotencia y uninstall) y emite un log JSONL encadenado con SHA-256 en `~/.local/state/`.

## Uso rápido

```bash
# Ver qué haría sin tocar nada
bash setup-ai-governance.sh --dry-run

# Desplegar en los 3 targets (pide confirmación interactiva)
bash setup-ai-governance.sh

# CI controlado por una persona responsable
bash setup-ai-governance.sh --yes --targets=opencode

# Si el servidor MCP aún no está instalado
bash setup-ai-governance.sh --allow-missing-mcp

# Desinstalar lo gestionado por este script
bash setup-ai-governance.sh --uninstall
```

Equivalente en PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup-ai-governance.ps1 -DryRun
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup-ai-governance.ps1 -Targets opencode -Yes
pwsh -NoProfile -File ./setup-ai-governance.ps1 -Uninstall
```

## Opciones

| Opción | Efecto |
|---|---|
| `--dry-run` / `-DryRun` | Solo muestra lo que haría, sin modificar nada |
| `--yes` / `-Yes` | Acepta el gate humano (solo CI controlado) |
| `--allow-missing-mcp` / `-AllowMissingMcp` | Permite desplegar sin el binario MCP |
| `--force` / `-Force` | Sobrescribe archivos sin marker de este script |
| `--no-backup` / `-NoBackup` | No crea backups `.bak.<timestamp>.<PID>` |
| `--uninstall` / `-Uninstall` | Borra los archivos registrados en el state file |
| `--targets=` / `-Targets` | CSV de targets; válidos: opencode, gemini, claude, all |

## Variables de entorno

- `AI_AGENT_NAME_OPENCODE/GEMINI/CLAUDE` — trailer `Co-Authored-By` desplegado
- `AI_AGENT_DISPLAY_OPENCODE/GEMINI/CLAUDE` — firma de PR desplegada
- `AI_MCP_VERSION`, `AI_MCP_SHA256` — sobrescriben los valores de `config/ai-mcp.lock` al actualizar el MCP

Todas las identidades se validan con una allowlist de caracteres antes de interpolarse en prompts.

## Notas importantes

- Los scripts escriben en `$HOME`, **no en este repositorio**.
- **Gate humano:** sin `--dry-run`, se pide confirmación interactiva; en sesiones no interactivas es obligatorio `--yes`.
- **Fail-fast MCP:** si falta `codebase-memory-mcp`, el script se detiene salvo `--allow-missing-mcp`. Se busca en `PATH`, `~/.local/bin`, `/usr/local/bin`, `/opt/homebrew/bin` y `~/AppData/Local/Programs/codebase-memory-mcp/` (ruta real del instalador de Windows), sin hardcodear el usuario. Versión y hash se verifican contra `config/ai-mcp.lock` (v0.12.1); actualiza el lock con las variables de entorno cuando cambies de versión.
- **Contrato versionado:** `opencode.json` fija `$schema` a `schemas/opencode-config-v1.json`, copia local del schema oficial. OpenCode no publica una URL versionada y el schema tiene `additionalProperties: false`, por lo que no se añaden campos propios.
- **Logs:** JSONL con `correlation_id`, `seq`, `prev_hash` y `hash` SHA-256; la ruta del home se enmascara. Permisos restrictivos (`umask 077` / ACL best-effort en Windows).
- **Kill switch:** crear `~/.config/ai-governance/ABORT` detiene el despliegue antes de escribir.
- **Rollback:** si falla un target, se revierten los archivos ya escritos.
- **Tests:** `bash tests/run_tests.sh` (requiere bash y python3; `pwsh` opcional para el test de paridad).
- Los dos scripts son un par: versión, changelog y contenido de `content/` sincronizados.

## Verificación

```bash
bash -n setup-ai-governance.sh
bash tests/run_tests.sh
```

```powershell
# Comprobar la cadena de hash de un log
$log = Get-ChildItem "$HOME\.local\state\ai-governance-setup.*.jsonl" | Select-Object -Last 1
# El payload original es la línea hasta ',"hash":' más el '}' final.
```

## Gobernanza

- `docs/APPLICABILITY.md` — perfil de aplicabilidad de los 25 pilares (12 y 22 son N.A. aquí).
- `docs/RISK_REGISTER.md` — riesgos, AI-BOM y criterios de aceptación.
- `docs/ARCHITECTURE.md` — diagramas Mermaid del flujo de despliegue.
- `docs/adr/` — decisiones arquitectónicas.

## Licencia

MIT — véase `LICENSE`.

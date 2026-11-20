# Registro de Riesgos Específicos de IA — `layrz-ia-scripts`

**Versión:** 1.1
**Fecha:** 2026-11-20
**Normativa:** ISO/IEC 23894, ISO/IEC 42001 Anexo A, NIST AI 600-1, OWASP Top 10 for Agentic Applications (2025)

Escala: probabilidad e impacto en `{Baja, Media, Alta}`. Estado verificado contra `tests/run_tests.sh` (PASS=6, FAIL=0).

| ID   | Pilar     | Riesgo                                                     | Prob. | Impacto | Mitigación implementada                                                                                    | Estado                                        |
|------|-----------|------------------------------------------------------------|-------|---------|------------------------------------------------------------------------------------------------------------|-----------------------------------------------|
| R-01 | 6, 20     | Logs en texto plano sin cadena SHA-256                     | Alta  | Alta    | Log JSONL con `correlation_id`, `seq`, `prev_hash` y `hash`; verificado en 30 eventos                      | Mitigado                                      |
| R-02 | 8         | Defectos de parser no detectados antes del despliegue      | Alta  | Alta    | Suite de golden files, idempotencia, casing y uninstall; 6 asertos en verde                                | Mitigado                                      |
| R-03 | 4         | Sobrescritura destructiva sin confirmación                 | Media | Alta    | Gate interactivo + `--yes`/`-Yes` + evento `APPROVAL`                                                      | Mitigado                                      |
| R-04 | 11, 21    | Inyección de contexto por variables de entorno             | Media | Alta    | Allowlist `[A-Za-z0-9 <>.@_-]{1,120}` antes de interpolar                                                  | Mitigado                                      |
| R-05 | 1, 9      | Ausencia de política, riesgo y arquitectura                | Alta  | Media   | `AI_POLICY.md`, `RISK_REGISTER.md`, `ARCHITECTURE.md`, ADRs, `APPLICABILITY.md`                            | Mitigado                                      |
| R-06 | 10        | MCP sin verificar / config apuntando a binario inexistente | Alta  | Media   | Fail-fast + `--allow-missing-mcp`; hash opcional vía `AI_MCP_SHA256`; detección en rutas reales de Windows | Parcial (versión/hash no fijados por defecto) |
| R-07 | 3, 13, 14 | Despliegue parcial sin rollback ni kill switch             | Media | Alta    | Rollback compensatorio, centinela `ABORT`, procedimiento documentado                                       | Mitigado                                      |
| R-08 | 15, 17    | Deriva entre ports y entre código y Markdown               | Alta  | Media   | Fuente única en `content/` + test de paridad byte-idéntico                                                 | Mitigado                                      |
| R-09 | 2         | Denylist evadible y allow global de MCP                    | Media | Media   | Permisos explícitos para flujo git/gh/tests; se eliminó `codebase-memory-mcp_*` global                     | Mitigado                                      |
| R-10 | 18        | Logs legibles por otros usuarios                           | Media | Media   | `umask 077` en Bash; ACL `icacls` best-effort en Windows                                                   | Mitigado                                      |
| R-11 | 24        | Fuga del nombre de usuario en logs                         | Alta  | Baja    | Enmascaramiento de la ruta del home antes de serializar                                                    | Mitigado                                      |
| R-12 | 23        | Esquema de config sin versión ni rollback probado          | Baja  | Media   | `--uninstall` probado en test 5; `$schema` sin versionar                                                   | Parcial                                       |
| R-13 | 5         | Falta de divulgación de IA en logs                         | Media | Baja    | Evento `AI_DISCLOSURE` como primer evento de la cadena                                                     | Mitigado                                      |

## AI-BOM (Pilar 10)

| Componente                      | Versión      | Origen                                                                                   | Verificación                             |
|---------------------------------|--------------|------------------------------------------------------------------------------------------|------------------------------------------|
| `bash`                          | >= 4         | Sistema operativo                                                                        | Comprobación al arranque                 |
| Windows PowerShell / PowerShell | >= 5.1 / 7.x | Sistema operativo                                                                        | `#Requires -Version 5.1`                 |
| `jq` / `python3` / `python`     | variable     | Sistema operativo                                                                        | Opcionales; fallback seguro implementado |
| `codebase-memory-mcp`           | sin fijar    | PATH, `~/.local/bin`, `/usr/local/bin`, `/opt/homebrew/bin`, `~/AppData/Local/Programs/` | Hash opcional vía `AI_MCP_SHA256` (R-06) |

## Criterio de aceptación

Un riesgo se considera mitigado solo cuando existe evidencia ejecutable (test, log o documento) y ha sido verificado por revisión humana. Los riesgos **Parcial** quedan aceptados temporalmente con seguimiento en el próximo ciclo.

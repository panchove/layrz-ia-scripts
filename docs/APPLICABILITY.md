# Perfil de Aplicabilidad de los 25 Pilares — `layrz-ia-scripts`

**Versión:** 1.0
**Fecha:** 2026-11-20
**Propósito:** declarar qué pilares de `AI_GOVERNANCE.md`son aplicables a este repositorio, cuáles son parcialmente aplicables y cuáles son **N.A. justificado**. Evita exigir evidencias imposibles y mantiene la credibilidad del marco.

---

## 1. Naturaleza del sistema

Este repositorio es un **instalador determinista**: dos scripts autónomos (Bash y PowerShell) que generan Markdown y JSON a partir de una fuente de contenido única y los escriben en las raíces de configuración de agentes externos (OpenCode, Gemini/Antigravity, Claude Code).

- No contiene modelos de lenguaje, bucles agénticos, tool-calling, RAG, memoria persistente ni comunicación entre agentes.
- No contiene clientes de red propios (HTTP/gRPC/broker/base de datos). Sí *genera* configuración que habilita `webfetch`/`curl` en el agente destino.
- No procesa PII más allá de la ruta absoluta del directorio personal del usuario en los logs.

Por tanto, los pilares que presuponen autonomía, inferencia o comunicación distribuida **no son aplicables al código de este repo**, aunque sí forman parte del marco que se despliega a los agentes consumidores.

## 2. Matriz de aplicabilidad

| Pilar                            | Estado                  | justificación / evidencia exigible                                                                                                              |
|----------------------------------|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 — Gobernanza y riesgo IA       | Aplicable               | `docs/AI_POLICY.md`, `docs/RISK_REGISTER.md`                                                                                                    |
| 2 — Seguridad agentica           | Aplicable (parcial)     | Config generada con allow/deny; sin runtime agéntico propio. No se exige red-teaming de un agente inexistente.                                  |
| 3 — Fail-safe                    | Aplicable               | Salida atómica, rollback multi-target, kill switch por archivo centinela                                                                        |
| 4 — Supervision humana           | Aplicable               | Gate interactivo + flag `--yes` para CI, registro de aprobación                                                                                 |
| 5 — Transparencia                | Aplicable               | Divulgación IA en logs y en plantillas de commit/PR                                                                                             |
| 6 — Auditabilidad SHA-256        | Aplicable               | Log JSONL con cadena SHA-256 (`prev_hash`)                                                                                                      |
| 7 — Calidad ISO 25010            | Aplicable (ligero)      | Métricas de los propios scripts: cobertura de tests de paridad e idempotencia                                                                   |
| 8 — Pruebas ISO 29119            | Aplicable               | `tests/` con golden files, idempotencia, uninstall y regresión de casing                                                                        |
| 9 — Arquitectura / ciclo de vida | Aplicable               | `docs/ARCHITECTURE.md` + ADRs                                                                                                                   |
| 10 — Supply chain                | Aplicable               | Versión fija y hash del MCP; AI-BOM en `docs/RISK_REGISTER.md`                                                                                  |
| 11 — Memoria y contexto          | Aplicable (parcial)     | Sin RAG; sí sanitización de variables de entorno inyectadas en prompts                                                                          |
| 12 — Comunicación inter-agente   | **N.A.**                | No hay agentes concurrentes ni protocolos entre ellos                                                                                           |
| 13 — Despliegue progresivo       | Aplicable               | Dry-run + despliegue transaccional por targets + rollback                                                                                       |
| 14 — Incidentes                  | Aplicable (ligero)      | Procedimiento de contención documentado en la política                                                                                          |
| 15 — Clean Code                  | Aplicable               | Fuente única de contenido, funciones de responsabilidad única                                                                                   |
| 16 — DbC                         | Aplicable               | Pre/postcondiciones en escritura y sustitución de plantillas                                                                                    |
| 17 — Markdown sync               | Aplicable               | Este documento + reindexación MCP (bloqueada si el binario no está instalado)                                                                   |
| 18 — ISO 27001                   | Aplicable (ligero)      | Permisos restrictivos de logs; sin secretos en el repo                                                                                          |
| 19 — Idempotencia                | Aplicable               | State file + guards + tests de doble ejecución                                                                                                  |
| 20 — Observabilidad              | Aplicable               | Log estructurado con `correlation_id`                                                                                                           |
| 21 — Zero-hardcode               | Aplicable               | Config por entorno con validación fail-fast                                                                                                     |
| 22 — Resiliencia en redes        | **N.A. en los scripts** | No hay llamadas de red propias. Aplica solo a la config generada (timeouts en `webfetch`/`curl`), no a backoff/circuit breakers del instalador. |
| 23 — Compatibilidad              | Aplicable (ligero)      | Versión de script + `--uninstall` como rollback                                                                                                 |
| 24 — Privacidad PII              | Aplicable (ligero)      | Enmascaramiento de la ruta del home en logs                                                                                                     |
| 25 — Modelado Mermaid            | Aplicable (ligero)      | Un único diagrama del flujo de despliegue en `ARCHITECTURE.md`                                                                                  |

## 3. Regla de uso

Toda auditoría futura debe usar esta matriz. Un pilar marcado **N.A.** no genera hallazgo ni requiere evidencia en este repositorio; sigue siendo obligatorio en los sistemas agentices a los que da soporte el marco desplegado.

# ADR 0001 — Paridad entre ports y fuente única de contenido

**Estado:** Propuesto · **Fecha:** 2026-11-20 · **Pilares:** 15, 17

## Contexto

Los scripts `.sh` y `.ps1` contenían cada uno ~600 líneas de Markdown embebido en here-strings/here-docs. Esto provocó:

- deriva real en el bloque de permisos `bash` del `opencode.json` generado (patrones presentes solo en la versión PowerShell);
- drift documental en `README.md` tras el fix 2.2.3 (líneas 10 y 39 quedaron desactualizadas);
- alto coste de sincronización: cualquier cambio de contenido exigía editar dos archivos.

La regla local del repo exige que ambos scripts sean "ports fieles" con versión y changelog sincronizados.

## Decisión

1. Extraer todo el contenido literal a `content/` (5 archivos, con placeholders `__GOV_PATH__`, `__AI_AGENT_NAME__`, `__AI_AGENT_DISPLAY__`, `AI_AGENT_NAME_PLACEHOLDER`).
2. Cada script pasa a ser un adaptador delgado que carga esos archivos desde su propio directorio (`$PSScriptRoot` / `SCRIPT_DIR`) y aplica sustituciones.
3. Añadir un test de **golden files** que genera los artefactos con ambos scripts y verifica que son byte-idénticos.
4. Igualar el bloque de permisos `bash` en ambos adaptadores (unión de patrones), documentando que los patrones específicos de Windows son inofensivos en Unix y viceversa.

## Consecuencias

**Positivas:** una sola fuente de verdad; el test detecta deriva automáticamente; los scripts bajan de ~960 a ~500 líneas; se cumple Pilar 15 (DRY) y 17 (sync).

**Negativas:** los scripts dejan de ser un único archivo autocontenido: deben distribuirse junto con `content/`. Se mitiga documentando en README que el repo completo es la unidad de distribución.

## Alternativas rechazadas

- Mantener here-docs duplicados: rejected por la deriva ya observada.
- Generador único en Python: rechazado porque añade una dependencia prohibida por las reglas del repo.
- Plantillas con Jinja/Handlebars: rechazado por el mismo motivo.

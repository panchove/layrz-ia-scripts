# ADR 0002 — Validación JSON case-sensitive

**Estado:** Aceptado (implementado en 2.2.3) · **Fecha:** 2026-11-20 · **Pilares:** 8, 15, 16

## Contexto

`opencode.json` incluye claves de permisos que difieren solo en mayúsculas (`*secret*`, `*Secret*`, `*SECRET*`, `*credential*`, `*Credential*`) para cubrir globs case-sensitive en sistemas de archivos sensibles a mayúsculas.

`ConvertFrom-Json` de PowerShell construye un diccionario **case-insensitive** y rechaza ese JSON como inválido:

- PS 5.1: *"Cannot convert the JSON string because a dictionary ... contains the duplicated keys '*secret*' and '*Secret*'"*
- PS 7: *"keys with different casing. Please use the -AsHashTable switch instead"*

Esto provocó un falso negativo en la validación final: todos los archivos se escribieron correctamente pero el script terminó con `exit 1`.

## Decisión

Extraer la comprobación de sintaxis a una función de responsabilidad única `Test-JsonSyntax` con un parser case-sensitive según la plataforma:

- **PS >= 6:** `ConvertFrom-Json -AsHashtable`.
- **PS 5.1:** `System.Web.Script.Serialization.JavaScriptSerializer` (`System.Web.Extensions`), con fallback que trata el error de casing de `ConvertFrom-Json` como evidencia de sintaxis válida.
- **Bash:** `jq` / `python3` (ya case-sensitive), con fallback que omite la validación y avisa.

## Consecuencias

El JSON se valida con la misma semántica en los tres entornos. El error de validación vuelve a ser fiable. Se añade un test de regresión que contiene explícitamente las claves problemáticas.

## Alternativas rechazadas

- Eliminar las variantes de mayúsculas del JSON: rechazado porque debilita la protección de archivos `mySecret*` en sistemas case-sensitive.
- Usar `-AsHashtable` en PS 5.1: no existe en esa versión.
- Relajar la validación con un `try/catch` genérico: rechazado porque enmascararía JSON realmente inválido (violación del Pilar 3 / fail-safe).

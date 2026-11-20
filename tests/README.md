# Suite de pruebas — layrz-ia-scripts

Ejecutar desde la raíz del repositorio:

```bash
bash tests/run_tests.sh
```

## Requisitos

| Herramienta | Uso | Obligatoria |
|---|---|---|
| `bash` >= 4 | Ejecutar scripts y suite | Sí |
| `python3` o `python` (o `jq`) | Validación JSON y verificación de hash | Sí para cobertura completa |
| `sha256sum` / `shasum` / `openssl` | Hash de snapshot | Sí (una de ellas) |
| `pwsh` | Test de paridad entre ports | No (se omite si falta) |
| `sed`, `find`, `sort`, `diff` | Snapshots normalizados | Sí |

## Casos cubiertos (ISO/IEC/IEEE 29119)

1. **Paridad de ports:** genera artefactos con `.sh` y `.ps1` en un HOME aislado, normaliza la ruta del HOME y compara los hashes de todos los archivos. Detecta deriva futura entre adaptadores.
2. **Idempotencia:** dos ejecuciones consecutivas deben producir el mismo estado y el state file no debe duplicar entradas.
3. **Regresión de casing:** `opencode.json` debe ser válido y conservar `*secret*`, `*Secret*` y `*SECRET*` (bug corregido en 2.2.3).
4. **Cadena SHA-256:** para cada evento del `.jsonl`, se reconstruye el payload original (línea hasta `,"hash":` más `}`) y se verifica `hash` y `prev_hash`.
5. **Uninstall seguro:** se inyecta una ruta manipulada en el state file; el uninstall no debe borrar archivos fuera de las raíces gestionadas.
6. **Contrato versionado:** `$schema` del `opencode.json` debe apuntar al archivo `schemas/opencode-config-v1.json` vendorizado y existente.
7. **AI-BOM:** `config/ai-mcp.lock` debe contener versión `0.12.1` y un SHA-256 válido de 64 hexadecimales.

La suite crea un directorio temporal con `mktemp -d` y lo elimina al terminar (`trap EXIT`). No escribe en el `$HOME` real.

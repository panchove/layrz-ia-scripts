# Evaluación de Impacto de IA — `layrz-ia-scripts`

**Versión:** 1.0 · **Fecha:** 2026-11-20 · **Relación:** ISO/IEC 27701, EU AI Act Art. 27, Pilar 24

## 1. Descripción del tratamiento

El repositorio no envía datos a servicios de IA. Genera plantillas de instrucciones (AGENTS.md / GEMINI.md / CLAUDE.md), workflows de commit/PR y un log de auditoría local. La IA actúa únicamente como asistente humano durante el desarrollo.

## 2. Datos implicados

| Dato                                              | Categoría                        | Origen                           | Destino                      | Minimización                                                                              |
|---------------------------------------------------|----------------------------------|----------------------------------|------------------------------|-------------------------------------------------------------------------------------------|
| Ruta absoluta del home (`C:\Users\<usuario>\...`) | Identificador personal indirecto | Entorno del sistema              | Logs locales y JSON generado | Se enmascara en logs; en JSON es necesario para que el agente encuentre las instrucciones |
| `AI_AGENT_NAME_*` / `DISPLAY_*`                   | Configuración no personal        | Variables de entorno del usuario | Plantillas de commit/PR      | Validación con allowlist; valores por defecto públicos                                    |
| Contenido de `content/`                           | Código/documentación del repo    | Git                              | Config de agentes            | Sin datos personales                                                                      |
| `correlation_id` y hashes                         | Metadatos técnicos               | Generados en ejecución           | Log local                    | Sin información personal                                                                  |

No se tratan créditos, credenciales, datos biométricos, salud, ubicación ni datos de menores.

## 3. Afectados y riesgos

- **Usuarios del sistema:** exposición del nombre de usuario en logs compartidos (R-11). Mitigación: enmascaramiento.
- **Equipos de desarrollo:** inyección de instrucciones en prompts de agentes mediante variables de entorno (R-04). Mitigación: validación estricta.
- **Organización:** pérdida de trazabilidad de cambios de gobernanza (R-01). Mitigación: log encadenado.

No se identifica impacto significativo en derechos fundamentales: no hay decisiones automatizadas con efectos legales sobre personas.

## 4. Salvaguardas

1. No envío de datos a APIs de IA desde el instalador.
2. Enmascaramiento de la ruta personal en logs (Pilar 24).
3. Permisos `0600` en el log y `umask 077` durante la ejecución (Pilar 18).
4. Retención documentada: 90 días, con borrado manual o mediante política del sistema; no se implementa borrado automático para evitar destrucción no consentida.
5. Gate humano antes de escribir fuera del repositorio (Pilar 4).

## 5. Conclusión

El impacto de privacidad es **bajo**, condicionado a que se implementen las salvaguardas 2 y 3. La aprobación de este documento debe registrarse junto a la política de IA.

# AI_GOVERNANCE.md - Marco Normativo y Tecnico de Gobernanza de Agentes e Ingenieria de Software (25 Pilares)

**Version:** 2.2
**Alcance:** Todos los sistemas agenticos, servicios backend, middleware, flujos de IA autonoma/semi-autonoma y herramientas asistidas por modelos de lenguaje desarrollados, mantenidos u operados bajo este entorno.
**Proposito:** Establecer requisitos obligatorios, evidencias verificables y estandares internacionales de cumplimiento para garantizar seguridad, trazabilidad, supervision humana, calidad de codigo y resiliencia operativa.

---

## Pilar 1. Gobernanza y Gestion de Riesgos Especificos de IA
* **Normas de referencia:** ISO/IEC 42001:2023 (AIMS), ISO/IEC 23894 (Gestion de riesgos de IA), NIST AI 600-1 (Perfil de IA Generativa).
* **Requisitos obligatorios:** El agente debe operar dentro de un Sistema de Gestion de Inteligencia Artificial (SGAI/AIMS) formal con politicas aprobadas, roles definidos, evaluacion de riesgos especifica de IA y tratamiento documentado. Los controles tradicionales (ISO/IEC 27001) son insuficientes por si solos ante autonomia, alucinacion y deriva.
* **Evidencias exigidas:** Politica de IA aprobada, registro de riesgos especifico del agente, evaluacion de impacto algoritmico/de IA y controles del Anexo A de ISO/IEC 42001 aplicados.

## Pilar 2. Seguridad Especifica de Agentes Autonomos
* **Norma de referencia:** OWASP Top 10 for Agentic Applications (2025).
* **Requisitos obligatorios:** Diseno defensivo contra secuestro de objetivos (Goal Hijacking), mal uso de herramientas (Tool Misuse), abuso de identidad/privilegios, inyeccion de memoria/contexto, ejecucion de codigo no aislada, fallos en cascada y agentes rogue. Aplicacion estricta de minimo privilegio (scoped tokens), allowlists de herramientas y sandboxing.
* **Evidencias exigidas:** Modelado de amenazas OWASP Agentic Top 10, pruebas de red teaming y mitigaciones implementadas.

## Pilar 3. Diseno a Prueba de Fallos (Fail-Safe)
* **Norma de referencia:** IEEE 7009-2024.
* **Requisitos obligatorios:** Mecanismos deterministas de parada segura, degradacion controlada ante fallos del LLM, herramientas o red, limites estrictos de iteracion (max_iterations) y disponibilidad de un Kill Switch independiente del razonamiento del modelo.
* **Evidencias exigidas:** Especificacion de estados seguros, pruebas de fallo inyectado, prueba exitosa del Kill Switch y certificacion interna del nivel de fail-safe.

## Pilar 4. Supervision Humana Efectiva y Escalado
* **Normas de referencia:** EU AI Act, Art. 14 y EN 18229-3.
* **Requisitos obligatorios:** Toda decision o accion de alto impacto debe estar protegida por puntos de control humanos explicitos (Human-in-the-Loop gates) que permitan aprobar, modificar o rechazar antes de ejecutar. El flujo debe bloquearse tecnicamente hasta recibir confirmacion humana verificada.
* **Evidencias exigidas:** Matriz de decisiones por nivel de riesgo, registro persistente de aprobaciones humanas y pruebas automatizadas de bloqueo sin intervencion.

## Pilar 5. Transparencia y Divulgacion de Identidad
* **Norma de referencia:** EU AI Act, Art. 50(1).
* **Requisitos obligatorios:** El agente debe revelar de forma clara e inequivoca que es un sistema de Inteligencia Artificial y en nombre de que organizacion actua en cada interaccion relevante y puntos de autorizacion, validacion o reporte. Prohibido suplantar identidades.
* **Evidencias exigidas:** Textos de divulgacion en interfaz/API, registro de entrega de divulgacion y pruebas de interaccion.

## Pilar 6. Auditabilidad con Registro a Prueba de Manipulacion
* **Normas de referencia:** IETF Agent Audit Trail (AAT) y EU AI Act, Art. 12.
* **Requisitos obligatorios:** Toda accion relevante (razonamiento, invocacion de herramientas, parametros, cambios de estado, aprobaciones humanas y nivel de confianza) debe registrarse en JSON estructurado enlazado criptograficamente mediante hash SHA-256 (prev_hash + evento actual) en almacenamiento append-only.
* **Evidencias exigidas:** Esquema JSON del log conforme a IETF AAT, cadena de hash SHA-256 verificable, politica de retencion y prueba de integridad.

## Pilar 7. Calidad de Producto Software Medible
* **Norma de referencia:** ISO/IEC 25010:2023.
* **Requisitos obligatorios:** Evaluacion medible bajo las caracteristicas de calidad de ISO/IEC 25010: adecuacion funcional, eficiencia de desempeno, compatibilidad, capacidad de interaccion, fiabilidad, seguridad, mantenibilidad y flexibilidad.
* **Evidencias exigidas:** Tablero/reporte de metricas cuantitativas (SLOs/KPIs: tasa de exito, latencia p95, MTBF, complejidad ciclomatica) y revision de arquitectura.

## Pilar 8. Pruebas y Verificacion Conforme a Estandares
* **Norma de referencia:** ISO/IEC/IEEE 29119.
* **Requisitos obligatorios:** Estrategia documentada, repetible y trazable a requisitos: pruebas unitarias, de integracion, de sistema, de aceptacion y suites especificas de IA (robustez adversaria, sesgos, tasa de alucinacion, fidelidad al contexto/grounding y resistencia a inyeccion).
* **Evidencias exigidas:** Plan de pruebas, matriz de trazabilidad, eval datasets versionados y criterios de salida en CI/CD.

## Pilar 9. Ciclo de Vida y Arquitectura Documentados
* **Normas de referencia:** ISO/IEC/IEEE 42010:2022 e ISO/IEC/IEEE 12207:2026.
* **Requisitos obligatorios:** Definicion formal de procesos de ciclo de vida (concepcion, desarrollo, operacion, mantenimiento y retirada) y descripcion arquitectonica detallada (componentes, flujos de datos, fronteras de confianza, interfaces, dependencias y ADRs).
* **Evidencias exigidas:** Documento de arquitectura ISO 42010 (diagramas C4 y ADRs) y procesos de ciclo de vida alineados a ISO 12207.

## Pilar 10. Seguridad de la Cadena de Suministro de IA
* **Norma de referencia:** OWASP Top 10 for Agentic Applications (Supply Chain).
* **Requisitos obligatorios:** Modelos, adaptadores, system prompts, servidores MCP, herramientas y dependencias inventariados, verificados criptograficamente, versionados con version exacta (sin etiquetas flotantes) y autorizados. Prohibida la carga dinamica externa en ejecucion.
* **Evidencias exigidas:** Inventario (AI-BOM/SBOM), verificacion de hashes/firmas y politica de procedencia.

## Pilar 11. Control de Memoria y Contexto
* **Norma de referencia:** OWASP Top 10 for Agentic Applications (Inyeccion de memoria/contexto).
* **Requisitos obligatorios:** Politica explicita de retencion (TTL), finalidad y borrado verificable. Aislamiento estricto entre system prompt y datos externos; validacion y sanitizacion obligatoria antes de escribir o recuperar datos de memoria persistente o RAG.
* **Evidencias exigidas:** Diseno de arquitectura de memoria, pruebas contra inyeccion indirecta de contexto/envenenamiento de RAG y mecanismo de borrado.

## Pilar 12. Comunicacion Segura entre Agentes
* **Norma de referencia:** OWASP Top 10 for Agentic Applications (Comunicacion insegura entre agentes).
* **Requisitos obligatorios:** En arquitecturas multi-agente, toda comunicacion debe estar mutuamente autenticada (mTLS o JWT firmado de corta duracion), cifrada en transito, validada contra esquemas estrictos y protegida contra ataques de repeticion (replay attacks).
* **Evidencias exigidas:** Especificacion de protocolo inter-agente, configuracion mTLS/JWT y pruebas de seguridad.

## Pilar 13. Despliegue Progresivo y Reversibilidad
* **Normas de referencia:** DevSecOps / MLOps e ISO/IEC/IEEE 12207.
* **Requisitos obligatorios:** Despliegues graduales mediante canary releases, shadow mode o feature flags con monitoreo activo de deriva (drift) y capacidad de rollback rapido, automatizado y probado hacia la ultima version estable.
* **Evidencias exigidas:** Pipeline de despliegue progresivo, alertas de deriva y registro de prueba exitosa de rollback.

## Pilar 14. Gestion de Incidentes Especifica de Agentes
* **Normas de referencia:** ISO/IEC 42001 y NIST AI RMF.
* **Requisitos obligatorios:** Procedimiento operativo especifico ante incidentes provocados por el agente: deteccion, contencion/aislamiento inmediato (revocacion de credenciales, deshabilitacion de herramientas o activacion de Kill Switch sin tumbar el resto del sistema), erradicacion, recuperacion y analisis post-mortem.
* **Evidencias exigidas:** Plan de respuesta a incidentes de IA (AI Incident Response Playbook), evidencia de simulacros y registro historico de incidentes.

## Pilar 15. Calidad de Codigo, Clean Code y Clear Code
* **Normas de referencia:** Principios SOLID, Clean Code, Clear Code y estandares idiomaticos del lenguaje.
* **Requisitos obligatorios:** El codigo fuente debe ser autoexplicativo, altamente legible, con nombres expresivos y funciones de responsabilidad unica (SRP), alta cohesion y bajo acoplamiento (DRY). Prohibido el codigo muerto, comentarios redundantes y complejidad ciclomatica excesiva.
* **Evidencias exigidas:** Analisis estatico/linters aprobados sin advertencias criticas y revision de codigo bajo estandares SOLID/Clean Code.

## Pilar 16. Diseno por Contrato (Design by Contract - DbC)
* **Normas de referencia:** Ingenieria de software formal orientada a contratos (Bertrand Meyer).
* **Requisitos obligatorios:** Toda funcion, metodo o endpoint critico debe definir y validar explicitamente Precondiciones (validaciones estrictas de entrada antes de ejecutar), Postcondiciones (garantias del resultado de salida) e Invariantes (estado valido del objeto o sistema).
* **Evidencias exigidas:** Validadores de contrato/esquema idiomaticos (ej. Pydantic, guards, aserciones) y pruebas unitarias de violacion de pre/postcondiciones.

## Pilar 17. Sincronizacion Bidireccional Codigo-Documentacion (Markdown Sync)
* **Norma de referencia:** ISO/IEC/IEEE 12207 (Gestion de la configuracion y documentacion).
* **Requisitos obligatorios:** Ninguna modificacion de arquitectura, firmas de funciones publicas, contratos de API, esquemas de base de datos o logica de negocio puede considerarse terminada sin actualizar simultaneamente el archivo Markdown (.md) correspondiente y reindexar la memoria de contexto (codebase-memory-mcp).
* **Evidencias exigidas:** Commits/entregas donde los archivos .md reflejan fielmente el estado actual del codigo fuente.

## Pilar 18. Seguridad de la Informacion y Cumplimiento Corporativo
* **Normas de referencia:** ISO/IEC 27001:2022 (SGSI) e ISO/IEC 42001:2023 (SGAI).
* **Requisitos obligatorios:** Todo codigo que procese datos operativos, credenciales, sesiones o integraciones debe aplicar controles de acceso, cifrado en transito y reposo, trazabilidad y segregacion de funciones conforme a ISO/IEC 27001, ademas de los controles de IA de ISO/IEC 42001 cuando corresponda.
* **Evidencias exigidas:** Controles tecnicos trazables al Anexo A de ISO/IEC 27001 y evaluacion de cumplimiento aplicable.

## Pilar 19. Idempotencia y Tolerancia a Reintentos
* **Normas de referencia:** ISO/IEC 25010 (Fiabilidad - Tolerancia a fallos) y arquitectura de sistemas distribuidos.
* **Requisitos obligatorios:** Toda operacion que modifique estado (APIs de escritura, consumidores de colas/mensajeria, webhooks, procesamiento de eventos y herramientas de agentes) debe ser idempotente mediante claves de idempotencia (idempotency keys), transacciones atomicas o verificaciones de estado previas.
* **Evidencias exigidas:** Implementacion de idempotency keys en operaciones criticas y pruebas automatizadas de reenvio duplicado.

## Pilar 20. Observabilidad Estructurada y Trazabilidad Distribuida
* **Normas de referencia:** OpenTelemetry, ISO/IEC 25010 (Analizabilidad) e ISO/IEC 27001 (A.8.15 Registro de eventos).
* **Requisitos obligatorios:** Prohibido el uso de console.log, print() o fmt.Println() no estructurados en produccion. Todo servicio y agente debe emitir logs en JSON estructurado con niveles estandar e incluir un correlation_id / trace_id propagado entre servicios, colas y llamadas a herramientas.
* **Evidencias exigidas:** Logger estructurado configurado, propagacion de encabezados de traza y ausencia de salidas de consola en texto plano.

## Pilar 21. Gestion Segura de Secretos y Configuracion (Zero-Hardcode)
* **Normas de referencia:** ISO/IEC 27001 (A.8.24 Criptografia / Gestion de claves) y OWASP ASVS.
* **Requisitos obligatorios:** Prohibicion absoluta de incluir credenciales, tokens, llaves privadas o cadenas de conexion fijas en el codigo fuente o historial de Git. Toda configuracion debe inyectarse por entorno validado al arranque (fail-fast config validation) o gestores de secretos y enmascararse en los logs.
* **Evidencias exigidas:** Validacion estricta de configuracion al inicio del proceso, escaneo de secretos y enmascaramiento en logs.

## Pilar 22. Resiliencia en Comunicaciones Externas e Integraciones
* **Normas de referencia:** ISO/IEC 25010 (Fiabilidad) e IEEE 7009.
* **Requisitos obligatorios:** Ninguna llamada de red (HTTP, gRPC, bases de datos, brokers de mensajeria o APIs de LLMs) puede realizarse sin timeouts explicitos de conexion y lectura, politicas de Exponential Backoff con Jitter para errores transitorios y Circuit Breakers.
* **Evidencias exigidas:** Timeouts explicitos, politicas de reintento y circuit breakers verificables en todos los clientes externos.

## Pilar 23. Evolucion Segura de Contratos y Esquemas (Backward Compatibility)
* **Normas de referencia:** ISO/IEC/IEEE 12207 y Semantic Versioning (SemVer).
* **Requisitos obligatorios:** Todo cambio en APIs publicas, eventos o esquemas de base de datos debe mantener compatibilidad hacia atras o versionarse explicitamente (/v1/, /v2/). Las migraciones de BD deben seguir el patron Expand-and-Contract y contar con script de reversion (rollback).
* **Evidencias exigidas:** Contratos versionados (OpenAPI/Protobuf/JSON Schema) y migraciones de base de datos reversibles.

## Pilar 24. Privacidad por Diseno y Minimizacion de Datos
* **Normas de referencia:** ISO/IEC 27701 (Gestion de Informacion de Privacidad) e ISO/IEC 27001.
* **Requisitos obligatorios:** Procesar y enviar a modelos de IA unicamente los datos estrictamente necesarios. Enmascarar o anonimizar datos personales identificables (PII) antes de enviarlos a LLMs externos, entornos de prueba o logs de auditoria.
* **Evidencias exigidas:** Filtros de redaccion de PII (PII scrubbing) previos al envio a APIs de IA y politicas de anonimizacion en entornos no productivos.

## Pilar 25. Modelado Visual y Diagramas UML mediante Mermaid
* **Normas de referencia:** ISO/IEC/IEEE 42010 (Arquitectura de Sistemas y Software) y UML.
* **Requisitos obligatorios:** Generar diagramas UML unicamente cuando se necesite realmente para aclarar arquitecturas complejas, flujos criticos o contratos. Su representacion debe realizarse obligatoriamente mediante sintaxis Mermaid dentro de los archivos Markdown (.md).
* **Evidencias exigidas:** Diagramas Mermaid limpios y actualizados en la documentacion tecnica del repositorio.

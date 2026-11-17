# Fase 0 — Alcance cerrado y convenciones técnicas

**Proyecto:** Sistema de gestión y trazabilidad comercial para una inmobiliaria  
**Motor relacional:** PostgreSQL (administración con pgAdmin 4)  
**Nombre de la base de datos:** `inmobiliaria_mcs`  
**Modelos de referencia:** conceptual v2.3 · relacional BD_MCS v1.3

## Organización del repositorio

```text
documentacion/          Guía del curso, formulación, diccionario y entregables escritos
  00_alcance_y_convenciones.md
  01_formulacion_problema.md
  02_modelo_conceptual.md
  03_modelo_relacional_normalizacion_f3.md
  04_consultas_vs_preguntas_f4.md
  05_optimizacion_transacciones_f5.md
  06_informe_final_base_f6.md
  07_mongodb_nosql_f6.md
  evidencia/              Capturas para el PDF final (ver README)
  entregables/            Carpetas E1–E7 (empaquetar entregas; ver entregables/README.md)
  entregables.txt         Lista de requisitos por fase (guía del curso)
codigo/modelos/         Diagramas ER/EER y relacional (draw.io + JSON)
codigo/sql/             ... 03_consultas_f4.sql, 04_optimizacion_f5.sql, 05_transacciones_f5.sql
codigo/mongodb/         01–03 scripts f6 + seguimiento_eventos_seed.json (Entregable 6)
codigo/backup/          Respaldo pg_dump de inmobiliaria_mcs (Entregable 4)
```

Los archivos de fase llevan sufijo `_fN` a partir de la Fase 3 (ej. `_f3`, `_f4`).

## Convenciones que no cambian en el resto del semestre

- El dominio es el mismo del Entregable 1: proceso comercial inmobiliario (propiedades, prospectos, campañas, seguimiento y cierre).
- El núcleo es relacional. MongoDB no replica el esquema; cubre un fragmento semiestructurado (historial de seguimiento).
- Toda tabla, restricción y consulta debe poder rastrearse a una regla de negocio o a una pregunta de información.
- Scripts SQL pensados para ejecutarse en orden sobre la base `inmobiliaria_mcs` desde pgAdmin 4.

## Equipo

La guía del curso indica grupos de máximo 2 estudiantes. La profesora autorizó a este equipo de tres: Harold Burgos, Sofía Camelo y Juan Triana.

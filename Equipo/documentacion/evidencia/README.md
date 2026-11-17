# Carpeta de evidencias visuales (informe final)

Guarde aquí capturas PNG o JPG. En el informe Word/PDF use rutas relativas o inserte las imágenes manualmente.

| Archivo sugerido | Qué debe verse en pgAdmin / MongoDB |
|------------------|-------------------------------------|
| `f0_estructura_repo.png` | Explorador del proyecto (carpetas `documentacion/`, `codigo/sql/`, `codigo/modelos/`) |
| `f0_bd_creada.png` | Árbol pgAdmin: servidor → **Databases** → `inmobiliaria_mcs` |
| `f1_portada_equipo.png` | Portada borrador del informe con integrantes (opcional) |
| `f2_diagrama_conceptual.png` | Export draw.io **Modelo conceptual v2.3** (PNG, página completa) |
| `f3_diagrama_relacional.png` | Export draw.io **BD_MCS v1.3** |
| `f4_ddl_commit.png` | Messages tras ejecutar `01_ddl_f4.sql` (COMMIT exitoso) |
| `f4_conteos_tablas.png` | Resultado final de `03_consultas_f4.sql` (UNION ALL de conteos) |
| `f4_consulta01_inventario.png` | Primeras filas consulta pregunta **1** o vista `v_inventario_disponible` |
| `f4_consulta06_campanas.png` | Resultado pregunta **6** (campañas / canales) |
| `f4_consulta09_rank.png` | Resultado pregunta **9** (`RANK`, días sin cierre) |
| `f4_backup_propiedades.png` | Clic derecho `inmobiliaria_mcs` → Backup o archivo en `codigo/backup/inmobiliaria_mcs_f4.sql` |
| `f5_explain_7_antes.png` | Panel **Messages/Data** con plan EXPLAIN consulta 7 (bloque A1) |
| `f5_explain_9_despues.png` | Plan consulta 9 bloque C2 o D |
| `f5_transaccion_commit_16.png` | `BEGIN` + `registrar_cierre(16…)` + `COMMIT` en Messages |
| `f5_transaccion_commit_16_02.png` | SELECT de verificación: propiedad 3 `vendida`, solicitud `ganada` |
| `f5_transaccion_rollback_do.png` | NOTICES del bloque 3 (`oferta_id=1, pendiente`) |
| `f6_mongo_compass_coleccion.png` | Compass: colección `seguimiento_eventos` (36 documentos, fechas `ISODate`) |
| `f6_agregacion_canales.png` | Agregación A1: eventos por canal |
| `f6_agregacion_top_solicitudes.png` | Agregación A2: top oportunidades por interacciones |
| `f6_agregacion_canales_resultado.json` | Resultado A1 exportado (5 canales; no es el dump de la colección) |
| `f6_agregacion_top_solicitudes_resultado.json` | Resultado A2 (top 10) |

La carga reproducible de los 36 eventos es `codigo/mongodb/seguimiento_eventos_seed.json` (no un export parcial de Compass).

También puede adjuntar **`results/time.txt`** como anexo textual sin captura.
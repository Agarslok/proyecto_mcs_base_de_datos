# Entregable 5 — Optimización y transacciones

## Qué pide el curso

- Evidencia de planes **antes y después** (EXPLAIN/ANALYZE).
- Hipótesis, cambio aplicado y conclusión.
- Script o evidencia de la transacción.
- Escenario de concurrencia y justificación del nivel de aislamiento.

## Qué ya tenemos

| Requisito | Dónde está |
|-----------|------------|
| Scripts optimización + transacciones | ✅ `codigo/sql/04_optimizacion_f5.sql`, `05_transacciones_f5.sql` |
| Hipótesis, índices, conclusión escrita | ✅ `documentacion/05_optimizacion_transacciones_f5.md` |
| Tiempos y planes en texto | ✅ `results/time.txt` |
| EXPLAIN antes (consulta 7) | ✅ captura `f5_explain_7_antes.png` + bloque A1 |
| EXPLAIN después (consulta 9 reescrita) | ✅ `f5_explain_9_despues.png` + bloque D |
| Transacción COMMIT oferta 61 | Falta volver a capturar. Las de la oferta 16 muestran un segundo cierre de la propiedad 3 |
| ROLLBACK / atomicidad oferta 1 | ✅ `f5_transaccion_rollback_do.png` |
| Concurrencia + aislamiento | ✅ comentarios en `05` §4–5; función `cerrar_venta_con_bloqueo` |

## Qué falta en **esta carpeta**

| Ítem | Estado |
|------|--------|
| Copia de scripts `04` y `05` | ☐ |
| Copia de `time.txt` y/o `05_optimizacion_transacciones_f5.md` | ☐ |
| Evidencia EXPLAIN **C1/C2** (consulta 7 y 9 después de índices, mismo SQL que antes) | ⚠ opcional; en repo hay A1 + D; C1/C2 están en script pero sin PNG dedicado |
| Documento único E5 en PDF | ☐ |

## Idea clave para sustentación

- **Optimización:** medir (A) → índices (B) → remediar (C) → reescritura semántica (D); con datos chicos la consulta 7 puede seguir en Seq Scan.
- **Transacciones:** `registrar_cierre` + trigger R12; `BEGIN`/`COMMIT` vs bloque `DO` con excepción.
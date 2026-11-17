# Entregable 1 — Formulación del problema

**Título:** Sistema de gestión y trazabilidad comercial para una inmobiliaria: diseño e implementación de una base de datos relacional para integrar propiedades, prospectos, campañas de marketing y seguimiento comercial.

**Integrantes:** Harold Burgos, Sofía Camelo, Juan Triana  
**Fuente original:** `BD_propuesta.pdf` (septiembre 2026)  
**Actualización:** noviembre 2026 (alineada al modelo conceptual v2.3 / relacional v1.3)

## El proyecto en una frase

Diseñar e implementar una base de datos relacional para gestionar y dar trazabilidad al proceso comercial de una inmobiliaria, integrando propiedades, prospectos, campañas de marketing y actividades de seguimiento, con el propósito de facilitar la operación, el análisis de resultados y futuras automatizaciones.

---

## 1. Contexto

La empresa objeto del proyecto es una inmobiliaria de intermediación y comercialización de inmuebles. El resultado comercial depende de captar propiedades, promocionarlas y convertir el interés de terceros en una operación (venta o arriendo).

En la operación participan Marketing, Ventas y, de forma periférica, Finanzas y aspectos legales. El núcleo de información es la relación entre:

- las propiedades disponibles,
- las campañas y canales con los que se promocionan,
- las personas que manifiestan interés (prospectos),
- el seguimiento (visitas, ofertas) y el cierre.

Una misma persona puede interesarse en varias propiedades. Una propiedad puede generar varios prospectos, provenientes de campañas distintas. El sistema debe poder responder, de forma estructurada: quién mostró interés, en qué inmueble, por qué canal o campaña, qué seguimiento se hizo y cuál fue el resultado.

Precio, estado comercial, gasto publicitario y comisión importan para el análisis; no se modela contabilidad ni jurídica completa.

## 2. Problema

La actividad comercial genera información en archivos y herramientas sueltas. Eso impide una trazabilidad continua: al llegar un interesado no siempre se sabe qué propiedad le llamó la atención, de qué campaña viene, ni qué se hizo después.

Consecuencias actuales:

- duplicidad de prospectos y de propiedades;
- historial de interacción incompleto o perdido;
- seguimiento difícil cuando hay muchas propiedades y contactos a la vez;
- ruptura entre campaña y prospectos generados;
- imposibilidad de comparar canales por rendimiento;
- dependencia de procesos manuales.

La pregunta que guía el diseño:

> ¿Cómo diseñar una solución de gestión de información que integre y dé trazabilidad al proceso comercial de una inmobiliaria, relacionando propiedades, prospectos, campañas, canales y actividades de seguimiento, de modo que la información se consulte y se use después para análisis y automatización?

## 3. Propósito

Centralizar y estructurar el proceso comercial: propiedades, prospectos, campañas, canales, visitas, negociaciones y resultados.

Se busca mejorar trazabilidad, consistencia y disponibilidad, para consultar el estado de las oportunidades y el desempeño de inmuebles y campañas.

La estructura debe quedar lista para integraciones futuras (WhatsApp, anuncios, formularios). Esas conexiones **no** forman parte de esta implementación.

## 4. Alcance

| Frente | Incluye |
|--------|---------|
| Propiedades | Identificación, datos del inmueble, ubicación, precio de publicación, estado comercial y resultado de la operación cuando exista. |
| Prospectos y contactos | Identificación, contacto, interés por una o más propiedades y estado de la oportunidad. |
| Marketing | Campañas, canales, inmuebles promocionados, prospectos atribuibles y costos básicos. |
| Seguimiento | Visitas, responsable, fechas, feedback y estado. |
| Resultados | Cierre, valor de la operación y comisión para análisis. |

### Fuera de alcance

Sistema contable, nómina, gestión jurídica completa, automatización de WhatsApp, integración con Meta Ads, CRM como producto, data warehouse y modelos predictivos.

---

## 5. Reglas de negocio (actualizadas)

Base: las 12 reglas del Entregable 1. Se precisan R2, R6, R10 y R11 para que coincidan con el modelo aprobado y corregido (prospecto ≠ propietario).

| Id | Tema | Descripción | Dónde queda en el modelo |
|----|------|-------------|---------------------------|
| R1 | Identificación de propiedades | Toda propiedad tiene identificador único. La matrícula inmobiliaria también es única. | `propiedades.propiedad_id`, `matricula_inmobiliaria` |
| R2 | Propietarios | Una propiedad tiene uno o más propietarios registrados. El dueño **no** es la oportunidad comercial. | `propiedad_propietarios` |
| R3 | Promoción | Una propiedad puede promocionarse en una o varias campañas o publicaciones. | `campana_propiedades`, `publicaciones` |
| R4 | Campañas | Una campaña puede asociarse a una o varias propiedades. | `campana_propiedades` |
| R5 | Prospectos | Una persona puede mostrar interés por una o varias propiedades. | `solicitudes_propiedad` (N solicitudes por persona) |
| R6 | Oportunidad comercial | Cada solicitud relaciona **un prospecto** (`persona_id`) con **una propiedad** (`propiedad_id`). No se usa el vínculo de propietario. | `solicitudes_propiedad` |
| R7 | Seguimiento | Una oportunidad puede tener varias actividades de seguimiento, con fecha y responsable. | `visitas` (+ empleado) |
| R8 | Visitas | Toda visita pertenece a una oportunidad; por ella se conoce propiedad y prospecto. | `visitas.solicitud_id` |
| R9 | Negociación | Toda oferta pertenece a una oportunidad previa. | `ofertas.solicitud_id` |
| R10 | Trazabilidad de campaña | Si se conoce el origen, la solicitud se asocia a la campaña. Si el contacto llegó por otro medio, `campana_id` queda vacío. | `solicitudes_propiedad.campana_id` opcional |
| R11 | Estado comercial | La propiedad tiene estado: `disponible`, `en_negociacion`, `vendida`, `no_disponible`. | `propiedades.estado_comercial` |
| R12 | Cierre | Si la oportunidad cierra, se registran valor final, comisión y fechas de contrato. | `transacciones` |

Reglas de apoyo (no sustituyen las 12; evitan ambigüedad al implementar):

| Id | Descripción |
|----|-------------|
| R13 | Una persona puede ser a la vez propietario y prospecto; los roles viven en `persona_roles`. |
| R14 | La publicación lleva tipo de operación (venta o arriendo) y el precio vigente. |
| R15 | Según el tipo de inmueble, la propiedad puede tener detalle de construcción, de terreno, o ambos (casa sobre lote). |
| R16 | El valor de comisión se deriva de `valor_final * comision_porcentaje`; no se digita aparte. El motor la redondea a dos decimales. |

## 6. Preguntas de información

Estas diez preguntas son el contrato de las consultas SQL del Entregable 4.

| # | Pregunta |
|---|----------|
| 1 | ¿Cuáles son las propiedades actualmente disponibles y cuál es su precio, ubicación y estado comercial? |
| 2 | ¿Qué prospectos han mostrado interés en cada propiedad? |
| 3 | ¿Qué propiedades tienen actualmente más oportunidades comerciales activas? |
| 4 | ¿Cuál es el estado de seguimiento de cada prospecto interesado en una propiedad? |
| 5 | ¿Qué actividades de seguimiento, contactos y visitas se han realizado para cada oportunidad comercial? |
| 6 | ¿Qué campañas y canales de marketing han generado mayor cantidad de prospectos y oportunidades comerciales? |
| 7 | ¿Qué propiedades han generado mayor cantidad de prospectos, visitas y negociaciones? |
| 8 | ¿Qué oportunidades comerciales han llegado a una negociación o cierre y cuáles no han avanzado? |
| 9 | ¿Qué propiedades llevan más tiempo en comercialización sin generar un cierre? |
| 10 | ¿Cuál ha sido el resultado comercial y económico básico de las propiedades vendidas? |

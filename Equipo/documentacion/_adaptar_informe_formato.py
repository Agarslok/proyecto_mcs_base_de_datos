"""Adapta el informe largo de Harold a los archivos y cifras de Profe/."""
import shutil
from pathlib import Path

import docx
from docx.oxml.ns import qn

SRC = Path(
    r"C:\Users\agars\Documents\U\Sem 4\Materias\Bases de datos\proyecto"
    r"\Equipo\harold\Proyecto_BD_Inmobiliaria_MCS\informe"
    r"\Informe_Tecnico_Final_Inmobiliaria_MCS.docx"
)
OUT = Path(
    r"C:\Users\agars\Documents\U\Sem 4\Materias\Bases de datos\proyecto"
    r"\Equipo\documentacion\_informe_formato_profe.docx"
)


def set_text(paragraph, text: str) -> None:
    if paragraph.runs:
        paragraph.runs[0].text = text
        for run in paragraph.runs[1:]:
            run.text = ""
    else:
        paragraph.add_run(text)


def set_cell(cell, text: str) -> None:
    set_text(cell.paragraphs[0], text)
    for extra in cell.paragraphs[1:]:
        set_text(extra, "")


def strip_drawings(paragraph) -> None:
    element = paragraph._p
    for child in list(element.iter()):
        if child.tag in {qn("w:drawing"), qn("w:pict")}:
            parent = child.getparent()
            if parent is not None:
                parent.remove(child)


def main() -> None:
    shutil.copyfile(SRC, OUT)
    document = docx.Document(OUT)

    # Figuras de la prueba a escala y del notebook: no están en Profe/.
    for index in (169, 170, 226, 227, 230, 233, 236):
        strip_drawings(document.paragraphs[index])

    replacements = {
        12: (
            "La evaluación usa la carga que se puede restaurar: cerca de 52 propiedades, "
            "65 solicitudes y 18 transacciones, en E4_postgresql/backup/inmobiliaria_mcs_f4.sql. "
            "Medimos las consultas 7 y 9 con EXPLAIN ANALYZE antes y después de los índices "
            "(E5_optimizacion_transacciones/sql/04_optimizacion_f5.sql y time.txt). Con ese volumen "
            "el plan sigue en Seq Scan y los tiempos quedan por debajo de medio milisegundo. "
            "No armamos una copia de cientos de miles de filas: ese script no está en la entrega. "
            "El cierre se demuestra con el COMMIT de la oferta 61 y el rechazo de la oferta 1 "
            "(sql/05_transacciones_f5.sql y las capturas de E5). El aislamiento es READ COMMITTED "
            "más FOR UPDATE en cerrar_venta_con_bloqueo. MongoDB guarda el seguimiento en la "
            "colección seguimiento_eventos; la carga, el CRUD y las dos agregaciones están en "
            "E6_mongodb/scripts."
        ),
        19: (
            "El documento sigue el orden en que construimos la solución: la formulación del problema "
            "y los requerimientos (secciones 2 y 3), la evolución del diseño (sección 4), el modelo "
            "conceptual (sección 5), el modelo relacional y su normalización (sección 6), el diccionario "
            "de datos (sección 7), la implementación en PostgreSQL (sección 8), las consultas y sus "
            "resultados (sección 9), la optimización y las transacciones (sección 10) y el componente "
            "MongoDB (sección 11). Cierra con las conclusiones, la declaración de uso de inteligencia "
            "artificial, las referencias y los anexos. La guía del curso indica grupos de máximo dos "
            "estudiantes; la docente autorizó a este equipo de tres integrantes."
        ),
        60: (
            "La Figura 1 presenta el modelo conceptual del archivo "
            "E2_modelo_conceptual/modelo_conceptual_2.1.drawio. En cada entidad, # marca el "
            "identificador, * un atributo obligatorio y o uno opcional; los extremos de las líneas "
            "indican la cardinalidad y la participación. El diagrama se presenta en dos partes para "
            "que se lea. La imagen es E2_modelo_conceptual/f2_diagrama_conceptual.png."
        ),
        70: (
            "Nota. Elaboración del equipo en draw.io. Archivo editable: "
            "E2_modelo_conceptual/modelo_conceptual_2.1.drawio."
        ),
        87: (
            "La Figura 2 muestra el esquema de E3_modelo_relacional/modelo_relacional_2.0.drawio, "
            "con 24 tablas, tipos de dato, claves primarias (PK) y foráneas (FK). La imagen es "
            "E3_modelo_relacional/f3_diagrama_relacional.png."
        ),
        97: (
            "Nota. Elaboración del equipo en draw.io. Archivo editable: "
            "E3_modelo_relacional/modelo_relacional_2.0.drawio."
        ),
        140: (
            "El respaldo de esta entrega es E4_postgresql/backup/inmobiliaria_mcs_f4.sql, en texto "
            "plano. Se restaura con psql, no pegándolo en el Query Tool de pgAdmin, porque el volcado "
            "trae comandos de psql y bloques COPY. Ahí están las 24 tablas, la carga de 65 solicitudes "
            "y 18 transacciones, las vistas, registrar_cierre y cerrar_venta_con_bloqueo. El script "
            "01 define además el trigger trg_dueno_no_es_prospecto; ese disparador no alcanzó a "
            "quedar en el volcado. El COMMIT de la oferta 61 no está aplicado dentro del archivo: "
            "es la demostración del script 05."
        ),
        149: (
            "La Tabla 16 muestra el desempeño de los canales (P6) sobre el respaldo. De las 55 "
            "solicitudes que sí tienen campaña, Meta Ads reúne 21 y la web 15: juntas son 36 de 55. "
            "WhatsApp reúne 10, la feria inmobiliaria 7 y los referidos 2. Otras 10 solicitudes "
            "no tienen campaña (R10)."
        ),
        152: (
            "Nota. Conteos del equipo sobre E4_postgresql/backup/inmobiliaria_mcs_f4.sql. "
            "La consulta P6 une solicitudes con campañas, así que las 10 solicitudes con "
            "campana_id nulo se cuentan aparte."
        ),
        164: "10.2 Conclusión con los datos del curso",
        165: (
            "La hipótesis era que los índices sobre las claves foráneas de solicitudes, visitas y "
            "ofertas, y reescribir la consulta 7 con tres CTE, bajarían el tiempo. Lo medimos en "
            "E5_optimizacion_transacciones/sql/04_optimizacion_f5.sql. Los tiempos están en time.txt. "
            "La consulta 7 pasa de 0,298 ms a 0,428 ms y el plan sigue en Seq Scan. La consulta 9 "
            "con NOT IN pasa de 0,352 ms a 0,264 ms. La reescritura con NOT EXISTS tarda 0,422 ms "
            "de ejecución y 0,642 ms de planificación. Con unas 60 filas por tabla la diferencia es "
            "ruido. No construimos una copia de cientos de miles de propiedades."
        ),
        169: (
            "Los planes de esta carga están en E5_optimizacion_transacciones/time.txt. Hay capturas "
            "en evidencia/f5_explain_7_antes.png y evidencia/f5_explain_9_despues.png."
        ),
        170: "Figura 3. Planes de la carga del curso, en time.txt y en la carpeta evidencia de E5.",
        199: (
            "No adjuntamos una corrida automática de dos sesiones. El comportamiento que justificamos "
            "está en cerrar_venta_con_bloqueo, dentro de E5_optimizacion_transacciones/sql/"
            "05_transacciones_f5.sql y del anexo C. La función toma FOR UPDATE sobre la solicitud y "
            "la propiedad. Si la propiedad ya está vendida, o si ya hay una transacción no anulada "
            "sobre ella, no llama a registrar_cierre."
        ),
        204: "11. Componente MongoDB",
        217: (
            "La colección se carga con E6_mongodb/scripts/01_setup_y_carga_f6.js y con "
            "seguimiento_eventos_seed.json: 36 documentos. Cada uno guarda solicitud_id, persona_id "
            "y propiedad_id para cruzarlos con PostgreSQL. No hay en esta entrega un notebook ni un "
            "seed anterior con las correcciones aparte."
        ),
        220: (
            "El CRUD está en E6_mongodb/scripts/02_crud_f6.js: se inserta un evento de prueba de la "
            "solicitud 1, se consulta, se actualiza metadata.revisado y se elimina. La colección "
            "vuelve a 36 documentos."
        ),
        225: (
            "Nota. Elaboración del equipo a partir de E6_mongodb/scripts/03_agregaciones_f6.js y de "
            "evidencia/f6_agregacion_canales_resultado.json."
        ),
        227: "Agregación A1: eventos por canal sobre los 36 documentos del seed",
        230: (
            "Nota. Resultado en E6_mongodb/evidencia/f6_agregacion_canales_resultado.json: "
            "whatsapp 14, llamada 7, nota_interna 7, email 6, feria 2."
        ),
        232: (
            "Las visitas están en PostgreSQL y el resto del seguimiento en MongoDB. Las dos "
            "agregaciones de la sección anterior responden por canal y por solicitud. No hay en "
            "esta entrega una consulta que una los dos motores en un notebook. El cruce se hace "
            "con solicitud_id."
        ),
        233: "Figura 6. Resultados de las agregaciones, en los JSON de E6_mongodb/evidencia.",
        236: "Nota. Archivos f6_agregacion_canales_resultado.json y f6_agregacion_top_solicitudes_resultado.json.",
        239: (
            "El aprendizaje fue sostener la decisión con la medición que sí corrimos. En time.txt "
            "la consulta 7 pasa de 0,298 ms a 0,428 ms después de los índices y el plan sigue en "
            "Seq Scan. La consulta 9 cambia décimas de milisegundo. Con esta carga no se puede decir "
            "que un índice haya hecho más rápida la consulta. El cierre queda en una transacción: "
            "COMMIT de la oferta 61 y rechazo de la oferta 1, con READ COMMITTED y FOR UPDATE en "
            "cerrar_venta_con_bloqueo. MongoDB guarda el historial que la tabla visitas no modela "
            "bien. Las agregaciones cuentan eventos por canal y las solicitudes con más interacciones."
        ),
        248: (
            "Durante el proyecto utilizamos herramientas de inteligencia artificial generativa "
            "(Cursor y Claude, de Anthropic) como apoyo para revisar la normalización, redactar "
            "documentación, proponer parte de los scripts SQL y estructurar este informe. El código "
            "lo ejecutamos en PostgreSQL y en MongoDB, y los resultados los revisamos contra las "
            "reglas del negocio y contra los archivos de la carpeta Profe. Los integrantes asumimos "
            "las decisiones de diseño, el contenido del documento y la sustentación individual."
        ),
        359: (
            "-- Técnica: tres CTE que agregan cada tabla por separado y luego se unen. "
            "En la carga del curso el tiempo no baja; la dejamos porque no multiplica filas."
        ),
        361: "-- Versión del script E4_postgresql/sql/03_consultas_f4.sql.",
    }
    for index, text in replacements.items():
        set_text(document.paragraphs[index], text)

    # Tabla 2. Decisiones.
    table = document.tables[2]
    set_cell(
        table.rows[5].cells[1],
        "Con la carga del curso el plan sigue en Seq Scan. Los tres índices de clave foránea quedan para cuando haya más filas; no medimos una copia de 100.000 propiedades.",
    )
    set_cell(
        table.rows[6].cells[1],
        "Tres CTE, para no multiplicar filas. En esta carga el tiempo no baja.",
    )
    set_cell(
        table.rows[9].cells[0],
        "Al contar el respaldo, varias propiedades vendidas todavía tienen solicitudes abiertas",
    )
    set_cell(
        table.rows[9].cells[1],
        "No reescribimos 02_carga_f4.sql para pasarlas a perdida ni agregamos prospectos nuevos. La pregunta 3 se lee con ese dato.",
    )
    set_cell(
        table.rows[10].cells[0],
        "El seguimiento omnicanal vive en 36 documentos",
    )
    set_cell(
        table.rows[10].cells[1],
        "Seed y scripts en E6_mongodb/scripts. No hay un segundo seed ni un notebook de validación.",
    )

    # Tabla 11. Archivos, solo los de Profe.
    files = document.tables[11]
    rows = [
        ("E4_postgresql/sql/00_crear_base_f4.sql", "CREATE DATABASE inmobiliaria_mcs. Se ejecuta sobre la base postgres."),
        ("E4_postgresql/sql/01_ddl_f4.sql", "24 tablas, 30 FK, 30 CHECK, siete funciones y ocho triggers, incluida trg_dueno_no_es_prospecto."),
        ("E4_postgresql/sql/02_carga_f4.sql", "Carga sintética. El comentario del script espera 65 solicitudes y 18 transacciones."),
        ("E4_postgresql/sql/03_consultas_f4.sql", "Tres vistas y las diez consultas."),
        ("E5_optimizacion_transacciones/sql/04_optimizacion_f5.sql", "EXPLAIN ANALYZE de las consultas 7 y 9 con la carga del curso."),
        ("E5_optimizacion_transacciones/sql/05_transacciones_f5.sql", "COMMIT de la oferta 61, rechazo de una oferta no aceptada y cerrar_venta_con_bloqueo."),
        ("E5_optimizacion_transacciones/time.txt", "Tiempos de planificación y de ejecución de las consultas 7 y 9."),
        ("E4_postgresql/backup/inmobiliaria_mcs_f4.sql", "Respaldo en texto plano: carga, vistas, registrar_cierre y cerrar_venta_con_bloqueo. 18 transacciones."),
        ("E6_mongodb/scripts/", "01 carga, 02 CRUD, 03 agregaciones y seguimiento_eventos_seed.json (36 eventos)."),
        ("evidencia/", "Capturas de E4, E5 y E6: pgAdmin, Compass y los JSON de las agregaciones."),
    ]
    for offset, (name, content) in enumerate(rows, start=1):
        set_cell(files.rows[offset].cells[0], name)
        set_cell(files.rows[offset].cells[1], content)
    set_cell(files.rows[11].cells[0], "E2 y E3")
    set_cell(
        files.rows[11].cells[1],
        "Diagramas editables modelo_conceptual_2.1.drawio y modelo_relacional_2.0.drawio, con sus PNG.",
    )

    counts = document.tables[12]
    set_cell(counts.rows[4].cells[1], "65")
    set_cell(counts.rows[4].cells[3], "64")
    set_cell(counts.rows[7].cells[1], "18")

    results = document.tables[14]
    set_cell(
        results.rows[3].cells[2],
        "Cinco propiedades llegan a dos o más solicitudes abiertas, y las cinco ya figuran como vendidas: Chapinero 1 y Usaquen 2 (3 cada una); Teusaquillo 3, Cedritos 4 y El Poblado 5 (2 cada una).",
    )
    set_cell(
        results.rows[4].cells[2],
        "35 oportunidades abiertas: 17 nuevas, 10 en seguimiento y 8 en negociación.",
    )
    set_cell(
        results.rows[5].cells[2],
        "88 visitas. En las 73 que tienen calificación, el interés promedio es 3,03 sobre 5.",
    )
    set_cell(
        results.rows[6].cells[2],
        "Meta Ads 21, web 15, WhatsApp 10, feria inmobiliaria 7 y referidos 2. Otras 10 solicitudes no tienen campaña.",
    )
    set_cell(
        results.rows[7].cells[2],
        "Las propiedades 1 y 2 lideran: 4 solicitudes y 8 visitas cada una, y 6 ofertas cada una.",
    )
    set_cell(
        results.rows[8].cells[2],
        "18 oportunidades llegaron a cierre, 30 tuvieron oferta sin cerrar y 17 no recibieron oferta.",
    )
    set_cell(
        results.rows[9].cells[2],
        "34 propiedades sin cierre en el respaldo. Los días dependen de CURRENT_DATE; time.txt devuelve esas 34 filas.",
    )
    set_cell(
        results.rows[10].cells[2],
        "18 cierres por $7.869 millones, con $294,6 millones de comisión (3,75 % promedio).",
    )

    channels = document.tables[15]
    channel_rows = [
        ("Meta Ads", "21", "Leads Meta Q1 (8)"),
        ("web", "15", "Portales web abril (7)"),
        ("WhatsApp", "10", "WhatsApp referidos (6)"),
        ("feria inmobiliaria", "7", "Feria Corferias (4)"),
        ("referidos", "2", "Referidos asesores (2)"),
        ("Sin campaña (R10)", "10", "—"),
    ]
    for index, values in enumerate(channel_rows, start=1):
        for column, value in enumerate(values):
            set_cell(channels.rows[index].cells[column], value)

    money = document.tables[16]
    set_cell(money.rows[1].cells[1], "18")
    set_cell(money.rows[2].cells[1], "$7.869.000.000")
    set_cell(money.rows[3].cells[1], "$294.615.000")
    set_cell(money.rows[4].cells[1], "3,75 %")
    set_cell(money.rows[5].cells[1], "Diego Parra: 4 cierres, $62.305.000")

    scale = document.tables[18]
    scale_rows = [
        (
            "P7 antes de los índices",
            "Un índice bajaría el tiempo de las métricas por propiedad",
            "0,298 ms. Seq Scan",
            "0,428 ms después. Sigue en Seq Scan",
            "No hay mejora. La diferencia es ruido de la medición.",
        ),
        (
            "P9 con NOT IN, antes",
            "El índice aceleraría el anti-join",
            "0,352 ms",
            "0,264 ms después",
            "Sigue en Seq Scan. No se separa del ruido.",
        ),
        (
            "P9 con NOT EXISTS",
            "La reescritura bajaría planificación y ejecución",
            "Planificación 1,705 ms en la versión NOT IN",
            "Ejecución 0,422 ms; planificación 0,642 ms",
            "El plan es más claro. El tiempo de ejecución no baja.",
        ),
        (
            "Los ocho índices de sql/04",
            "Harían más rápida la consulta 7",
            "Plan en time.txt, 65 solicitudes",
            "El planificador no los usa en P7",
            "Quedan creados. No los presentamos como optimización lograda.",
        ),
        (
            "Tres CTE de la consulta 7",
            "Evitarían multiplicar filas de visitas y ofertas",
            "La versión con JOIN puede inflar filas",
            "Mismas propiedades, tiempo similar",
            "La dejamos por el resultado, no por un 46 % medido.",
        ),
    ]
    for index, values in enumerate(scale_rows, start=1):
        for column, value in enumerate(values):
            set_cell(scale.rows[index].cells[column], value)

    indexes = document.tables[19]
    for row in indexes.rows[1:]:
        decision = row.cells[1].text
        if decision.startswith("Se elimina"):
            set_cell(
                row.cells[1],
                "No aporta en esta carga",
            )
            set_cell(
                row.cells[2],
                "El script 04 lo crea. Con 65 solicitudes el plan de las consultas 7 y 9 no lo usa.",
            )

    sessions = document.tables[21]
    set_cell(sessions.rows[0].cells[0], "Qué cubre la función")
    set_cell(sessions.rows[0].cells[1], "Dónde está")
    set_cell(sessions.rows[0].cells[2], "Qué hace")
    set_cell(sessions.rows[1].cells[0], "Bloqueo de la solicitud y de la propiedad")
    set_cell(sessions.rows[1].cells[1], "sql/05_transacciones_f5.sql")
    set_cell(sessions.rows[1].cells[2], "FOR UPDATE antes de registrar el cierre")
    set_cell(sessions.rows[2].cells[0], "Propiedad ya vendida o con cierre vigente")
    set_cell(sessions.rows[2].cells[1], "Misma función, y también el respaldo")
    set_cell(sessions.rows[2].cells[2], "No llama a registrar_cierre")
    set_cell(sessions.rows[3].cells[0], "Dos sesiones al mismo tiempo")
    set_cell(sessions.rows[3].cells[1], "No hay script de esa corrida en Profe")
    set_cell(sessions.rows[3].cells[2], "No adjuntamos esa demostración")

    rubric = document.tables[24]
    set_cell(
        rubric.rows[2].cells[2],
        "Sección 5, Figura 1 y E2_modelo_conceptual/ (PDF, PNG y drawio).",
    )
    set_cell(
        rubric.rows[4].cells[2],
        "Secciones 7 y 8; E4_postgresql/sql/00 a 03; backup/inmobiliaria_mcs_f4.sql.",
    )
    set_cell(
        rubric.rows[6].cells[2],
        "Sección 10; sql/04 y sql/05; time.txt y evidencia/.",
    )
    set_cell(
        rubric.rows[7].cells[2],
        "Sección 11; E6_mongodb/scripts y E6_mongodb/evidencia.",
    )

    document.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()

"""Fase 5 · Demostración del escenario de concurrencia con dos sesiones reales.

Dos asesores cierran al mismo tiempo dos ofertas ACEPTADAS distintas de la misma
propiedad (en la copia temporal se crean dos prospectos con una oferta aceptada
cada uno sobre una propiedad disponible en venta). Se comparan tres formas:

  A. registrar_cierre, READ COMMITTED, sin bloqueo  -> la propiedad se vende dos veces
  B. cerrar_venta_con_bloqueo (FOR UPDATE + relectura del estado)  -> un solo cierre
  C. registrar_cierre con SERIALIZABLE  -> la segunda sesión recibe el error 40001

Cada escenario trabaja sobre una copia temporal de la base
(CREATE DATABASE ... TEMPLATE inmobiliaria_mcs), que se elimina al final:
los datos del proyecto no se modifican.

Uso (con inmobiliaria_mcs cargada con los scripts 01-05 y sin otras conexiones abiertas a ella):
    pip install "psycopg[binary]"
    set PGPASSWORD=<contraseña de postgres>        (Windows; en Mac/Linux: export)
    python sql/07_concurrencia_demo.py
Variables opcionales: PGHOST, PGPORT, PGUSER.
"""
import os
import threading
import time

import psycopg
from psycopg import errors, sql

BASE = dict(host=os.getenv("PGHOST", "localhost"), port=os.getenv("PGPORT", "5432"),
            user=os.getenv("PGUSER", "postgres"), password=os.getenv("PGPASSWORD", ""))
ORIGEN, COPIA = "inmobiliaria_mcs", "inmobiliaria_mcs_demo_concurrencia"


def admin():
    return psycopg.connect(**BASE, dbname="postgres", autocommit=True)


def copiar_base():
    with admin() as a:
        a.execute(sql.SQL("DROP DATABASE IF EXISTS {}").format(sql.Identifier(COPIA)))
        a.execute(sql.SQL("CREATE DATABASE {} TEMPLATE {}").format(sql.Identifier(COPIA), sql.Identifier(ORIGEN)))


def borrar_copia():
    with admin() as a:
        a.execute(sql.SQL("DROP DATABASE IF EXISTS {}").format(sql.Identifier(COPIA)))


def preparar_escenario(c):
    """En la copia: dos prospectos distintos con una oferta ACEPTADA cada uno sobre
    la misma propiedad disponible y publicada en venta (caso límite del negocio:
    el asesor acepta dos ofertas antes de formalizar el cierre)."""
    prop = c.execute("""
        SELECT p.propiedad_id FROM propiedades p
        JOIN publicaciones pub ON pub.propiedad_id = p.propiedad_id
        JOIN tipos_operacion t ON t.tipo_operacion_id = pub.tipo_operacion_id
        WHERE p.estado_comercial = 'disponible' AND t.nombre = 'venta'
        ORDER BY p.propiedad_id LIMIT 1""").fetchone()[0]
    prospectos = [r[0] for r in c.execute("""
        SELECT pe.persona_id FROM personas pe
        WHERE NOT EXISTS (SELECT 1 FROM propiedad_propietarios pp
                          WHERE pp.persona_id = pe.persona_id AND pp.propiedad_id = %s)
        ORDER BY pe.persona_id DESC LIMIT 2""", (prop,))]
    ofertas, valores = [], []
    for i, persona in enumerate(prospectos):
        sol = c.execute("""
            INSERT INTO solicitudes_propiedad (persona_id, propiedad_id, estado, presupuesto_cliente, requiere_financiacion)
            VALUES (%s, %s, 'en_negociacion', 400000000, FALSE) RETURNING solicitud_id""", (persona, prop)).fetchone()[0]
        valor = 350000000 + i * 5000000
        of = c.execute("""
            INSERT INTO ofertas (solicitud_id, estado_oferta, valor_ofertado, fecha_oferta)
            VALUES (%s, 'aceptada', %s, now()) RETURNING oferta_id""", (sol, valor)).fetchone()[0]
        ofertas.append(of); valores.append(valor)
    return prop, ofertas, valores


def escenario(titulo, funcion, nivel):
    copiar_base()
    conn = dict(**BASE, dbname=COPIA)
    with psycopg.connect(**conn, autocommit=True) as c:
        prop, ofertas, valores = preparar_escenario(c)
        empleado = c.execute("SELECT min(empleado_id) FROM empleados").fetchone()[0]
    print(f"\n=== {titulo} · {nivel} ===")
    print(f"Propiedad {prop}: ofertas aceptadas sin cierre {ofertas[0]} y {ofertas[1]}")
    s1, s2 = psycopg.connect(**conn), psycopg.connect(**conn)
    for s in (s1, s2):
        s.isolation_level = getattr(psycopg.IsolationLevel, nivel.replace(" ", "_"))
    llamada = f"SELECT {funcion}(%s, %s, %s, 3.0, CURRENT_DATE, NULL, 'cerrada')"
    s1.execute(llamada, (ofertas[0], empleado, valores[0]))
    print(f"Sesión 1: {funcion}(oferta {ofertas[0]}) -> ejecutado, sin confirmar (bloquea la fila de la propiedad)")
    resultado = {}

    def sesion2():
        t0 = time.time()
        try:
            s2.execute(llamada, (ofertas[1], empleado, valores[1]))
            s2.commit()
            resultado["msg"] = f"COMMIT -> confirmado (esperó {time.time() - t0:.1f} s)"
        except psycopg.Error as e:
            s2.rollback()
            tipo = "40001 serialización" if isinstance(e, errors.SerializationFailure) else "rechazado"
            resultado["msg"] = f"{tipo} tras esperar {time.time() - t0:.1f} s: {str(e).splitlines()[0]}"

    hilo = threading.Thread(target=sesion2)
    hilo.start()
    time.sleep(1.5)
    print(f"Sesión 2: {funcion}(oferta {ofertas[1]}) -> en espera del bloqueo...")
    s1.commit()
    print("Sesión 1: COMMIT -> confirmado")
    hilo.join()
    print(f"Sesión 2: {resultado['msg']}")
    with psycopg.connect(**conn) as c:
        n, estado = c.execute("""
            SELECT count(*), max(p.estado_comercial)
            FROM transacciones t JOIN ofertas o ON o.oferta_id = t.oferta_id
            JOIN solicitudes_propiedad s ON s.solicitud_id = o.solicitud_id
            JOIN propiedades p ON p.propiedad_id = s.propiedad_id
            WHERE s.propiedad_id = %s AND t.estado <> 'anulada'""", (prop,)).fetchone()
    print(f"Cierres registrados para la propiedad {prop}: {n} (estado {estado}) -> "
          f"{'ANOMALÍA: doble venta' if n > 1 else 'correcto: un solo cierre'}")
    s1.close(); s2.close()


if __name__ == "__main__":
    try:
        escenario("A. Sin bloqueo", "registrar_cierre", "READ COMMITTED")
        escenario("B. Con bloqueo y relectura del estado", "cerrar_venta_con_bloqueo", "READ COMMITTED")
        escenario("C. Sin bloqueo, aislamiento estricto", "registrar_cierre", "SERIALIZABLE")
    finally:
        borrar_copia()
    print("\nCopia temporal eliminada; inmobiliaria_mcs no se modificó.")

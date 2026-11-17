"""Genera PDF desde HTML de cada entregable (Edge headless, Windows)."""
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
EDGE = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
if not EDGE.is_file():
    EDGE = Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe")

JOBS = [
    (ROOT / "E1_formulacion" / "E1_formulacion_MCS.html", ROOT / "E1_formulacion" / "E1_formulacion_MCS.pdf"),
    (ROOT / "E2_modelo_conceptual" / "E2_modelo_conceptual.html", ROOT / "E2_modelo_conceptual" / "E2_modelo_conceptual.pdf"),
    (
        ROOT / "E3_modelo_relacional" / "E3_modelo_relacional_normalizacion.html",
        ROOT / "E3_modelo_relacional" / "E3_modelo_relacional_normalizacion.pdf",
    ),
    (
        ROOT / "E3_modelo_relacional" / "E3_evidencia_normalizacion_resumida.html",
        ROOT / "E3_modelo_relacional" / "E3_evidencia_normalizacion.pdf",
    ),
    (ROOT / "E4_postgresql" / "E4_consultas_vs_preguntas.html", ROOT / "E4_postgresql" / "E4_consultas_vs_preguntas.pdf"),
    (
        ROOT / "E5_optimizacion_transacciones" / "E5_optimizacion_transacciones.html",
        ROOT / "E5_optimizacion_transacciones" / "E5_optimizacion_transacciones.pdf",
    ),
    (ROOT / "E6_mongodb" / "E6_mongodb_nosql.html", ROOT / "E6_mongodb" / "E6_mongodb_nosql.pdf"),
]


def to_file_url(path: Path) -> str:
    return path.resolve().as_uri()


def print_pdf(html_path: Path, pdf_path: Path) -> None:
    pdf_path.parent.mkdir(parents=True, exist_ok=True)
    if pdf_path.is_file():
        pdf_path.unlink()
    url = to_file_url(html_path)
    subprocess.run(
        [
            str(EDGE),
            "--headless=new",
            "--disable-gpu",
            f"--print-to-pdf={pdf_path}",
            "--no-pdf-header-footer",
            url,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    deadline = time.time() + 30
    while time.time() < deadline:
        if pdf_path.is_file() and pdf_path.stat().st_size > 1000:
            return
        time.sleep(0.25)
    raise RuntimeError(f"No se generó {pdf_path}")


def main() -> None:
    if not EDGE.is_file():
        raise FileNotFoundError("Instala Microsoft Edge o ajusta la ruta en este script.")
    for html_path, pdf_path in JOBS:
        if not html_path.is_file():
            raise FileNotFoundError(html_path)
        print_pdf(html_path, pdf_path)
        print("OK", pdf_path.relative_to(ROOT))


if __name__ == "__main__":
    main()
import os
import re
import shutil

def organizar_proyecto():
    print("Iniciando la organización automática de tu documentación...")

    # 1. Crear la estructura física de carpetas si no existe
    carpetas = [
        'docs/guias',
        'docs/u1_definicion',
        'docs/u2_construccion',
        'docs/u3_integracion'
    ]
    for carpeta in carpetas:
        os.makedirs(carpeta, exist_ok=True)
        print(f" Directoria asegurado: {carpeta}")

    # 2. Mover archivos sueltos a sus respectivas carpetas de guías
    if os.path.exists('docs/guia_debezium.md'):
        shutil.move('docs/guia_debezium.md', 'docs/guias/debezium.md')
        print(" Archivo reubicado: docs/guia_debezium.md -> docs/guias/debezium.md")
    elif os.path.exists('docs/debezium.md'):
        shutil.move('docs/debezium.md', 'docs/guias/debezium.md')

    if os.path.exists('docs/comparativos.md'):
        shutil.move('docs/comparativos.md', 'docs/guias/comparativos.md')
        print(" Archivo reubicado: docs/comparativos.md -> docs/guias/comparativos.md")

    # 3. Parsear y dividir automáticamente 'documentacion.md' en los 18 archivos del nav
    path_documentacion = 'docs/documentacion.md'
    if os.path.exists(path_documentacion):
        print(f" Leyendo archivo maestro de documentación en {path_documentacion}...")
        with open(path_documentacion, 'r', encoding='utf-8') as f:
            content = f.read()

        # Separar el documento por los encabezados H2 (ej: ## 1. , ## 2. , etc.)
        sections = re.split(r'\n## ', content)
        
        # Mapeo exacto de los encabezados a las rutas físicas del nav
        mapping = {
            '1. ': 'docs/u1_definicion/datos_generales.md',
            '2. ': 'docs/u1_definicion/datos_generales.md',  # 1 y 2 van juntos en el mismo archivo
            '3. ': 'docs/u1_definicion/problema_objetivo.md',
            '4. ': 'docs/u1_definicion/kpis.md',
            '5. ': 'docs/u2_construccion/arquitectura.md',
            '6. ': 'docs/u2_construccion/fuente_oltp.md',
            '7. ': 'docs/u2_construccion/pipeline.md',
            '8. ': 'docs/u2_construccion/data_warehouse.md',
            '9. ': 'docs/u3_integracion/modelo_semantico.md',
            '10.': 'docs/u3_integracion/dashboard.md',
            '11.': 'docs/u3_integracion/validacion.md',
            '12.': 'docs/u3_integracion/trazabilidad.md',
            '13.': 'docs/u3_integracion/calidad_gobierno.md',
            '14.': 'docs/u3_integracion/hallazgos_decisiones.md',
            '15.': 'docs/u3_integracion/sustentacion.md',
            '16.': 'docs/u3_integracion/evidencias.md',
            '17.': 'docs/u3_integracion/aporte.md',
            '18.': 'docs/u3_integracion/conclusiones.md',
        }

        # Inicializar el diccionario de contenidos
        split_contents = {path: "" for path in mapping.values()}

        # Clasificar cada sección en su archivo destino
        for section in sections[1:]:
            matched = False
            for prefix, target_path in mapping.items():
                if section.strip().startswith(prefix):
                    split_contents[target_path] += "## " + section + "\n\n"
                    matched = True
                    break
            if not matched:
                # Si algún texto queda flotando, lo mandamos a conclusiones de forma segura
                split_contents['docs/u3_integracion/conclusiones.md'] += "## " + section + "\n\n"

        # Escribir físicamente cada archivo resultante de manera limpia
        for path, body_content in split_contents.items():
            if body_content.strip():
                # Añadir un título formal basado en la carpeta si es necesario
                with open(path, 'w', encoding='utf-8') as out_file:
                    out_file.write(body_content.strip() + "\n")
                print(f" Archivo generado y estructurado: {path}")

        # Renombrar el archivo maestro a backup para que MkDocs no lance advertencias de archivos sueltos
        backup_path = path_documentacion + ".bak"
        if os.path.exists(backup_path):
            os.remove(backup_path)
        os.rename(path_documentacion, backup_path)
        print(f" Resguardado: {path_documentacion} renombrado de forma segura a {backup_path}")

        print("\n Proceso completado con éxito. ¡Tu estructura está lista para compilar!")
    else:
        print(f"⚠ Alerta: No se encontró el archivo maestro {path_documentacion} para realizar la división.")

if __name__ == "__main__":
    organizar_proyecto()
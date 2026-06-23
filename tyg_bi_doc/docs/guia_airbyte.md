# Guía de Ingesta con Airbyte

Esta guía detalla el proceso técnico para implementar, configurar y ejecutar el pipeline de extracción y carga (EL) de datos para T&D Angeles E.I.R.L., utilizando **Airbyte** como motor principal.

---

## 1. Introducción
En el entorno de distribución de kits DIRECTV de T&D Angeles, los datos operativos se generan en una base de datos transaccional MySQL. Para evitar sobrecargar este sistema con consultas analíticas pesadas, implementamos una arquitectura de ingesta que replica estos datos hacia un Data Warehouse centralizado en PostgreSQL utilizando Airbyte.

## 2. Objetivo
Automatizar y estandarizar la extracción de datos (tablas de ventas, asesores, PDV, oficinas y metas) desde el sistema OLTP (MySQL) y su carga en bruto (Raw Data) hacia el DataMart (PostgreSQL), preparando el terreno para su posterior transformación con dbt.

## 3. Qué contiene hoy
El repositorio y la arquitectura actual contienen:

* Archivos de configuración y *scripts* para levantar la base de datos de origen (MySQL) y destino (PostgreSQL).
* Configuración de contenedores Docker para ejecutar la interfaz y el *scheduler* de Airbyte.
* Definición de la conexión (Source - Destination) para la replicación de tablas de negocio.

## 4. Qué hace este stack
1. **Conecta:** Establece un puente seguro entre MySQL y PostgreSQL.
2. **Extrae:** Lee los registros de ventas y catálogos directamente de MySQL.
3. **Carga:** Deposita los datos en su formato original en un esquema transitorio (generalmente `public` o `airbyte_internal` / `raw` en Postgres).
4. **Tipifica:** Realiza una normalización básica de los tipos de datos en la llegada.

## 5. Qué no hace todavía
* **Orquestación automatizada:** Actualmente no cuenta con una herramienta como Apache Airflow o Dagster; las ejecuciones de Airbyte y dbt dependen de activaciones manuales o *cron jobs* básicos en el host.
* **Transformación (T):** Airbyte **solo** hace Extracción y Carga (EL). La limpieza, unión y lógicas de negocio (como el cálculo de ingresos por tipo de canal) están delegadas estrictamente a dbt.

## 6. Origen MySQL
El sistema fuente es una base de datos relacional MySQL que soporta la operación diaria de la empresa. Contiene un histórico de más de 1500 transacciones mensuales de salidas y activaciones de kits.

## 7. Conectores incluidos
* **Source:** `MySQL` (Conector oficial de Airbyte para lectura de bases relacionales).
* **Destination:** `PostgreSQL` (Conector oficial de Airbyte para escritura en bases relacionales).

## 8. Cuándo usar este enfoque
Este enfoque (Batch / Micro-batch con Airbyte) es ideal para T&D Angeles porque:

1. Las decisiones gerenciales sobre metas y stock no requieren latencia de milisegundos (tiempo real), sino cortes diarios o intradía (cada 6 o 12 horas).
2. Permite desacoplar el servidor de producción del esfuerzo computacional de los dashboards de Power BI.

## 9. CDC (Change Data Capture)
Aunque actualmente las cargas pueden funcionar en modo "Full Refresh" o "Incremental" (basado en columnas como `fecha_venta`), Airbyte soporta **CDC** leyendo el *binlog* (Binary Log) de MySQL. Esto significa que puede identificar exactamente qué filas de kits insertaron, actualizaron (ej: pasaron de "Inactivo" a "Activo") o eliminaron, sincronizando solo esos cambios hacia PostgreSQL para mayor eficiencia.

## 10. Componentes

### 10.1 MySQL
Servidor transaccional que contiene las tablas: `ventas`, `vendedores`, `pdv`, `oficinas` y `metas`.

### 10.2 PostgreSQL DW
Data Warehouse analítico. Recibe los datos crudos en un esquema inicial y posteriormente aloja los esquemas intermedios y el DataMart final (`dw_marts`) modelado en estrella.

## 11. Requisitos
Para desplegar este ecosistema en una máquina local o servidor, necesitas:

* **Docker y Docker Compose** instalados.
* **DBeaver** (o cualquier cliente SQL) para validación.
* **Git** para clonar el repositorio del proyecto.
* **dbt Core** (o dbt CLI) instalado en el entorno de desarrollo.
* Al menos 8GB de RAM y 20GB de disco disponible en el host.

## 12. Cómo levantar el stack
Para levantar la interfaz de Airbyte localmente mediante Docker:

1. Clona el repositorio oficial de Airbyte (si se usa la versión local open-source):
```bash
git clone https://github.com/airbytehq/airbyte.git
cd airbyte
```
2. Ejecuta el script de inicio o levanta los contenedores:
```bash
./run-ab-platform.sh
# O alternativamente: docker-compose up -d
```
3. Espera unos minutos y accede a la UI desde tu navegador en `http://localhost:8010`.

![Inicio Airbyte](assets/airbyte_inicio.png)

## 13. Cómo poblar el origen MySQL
Si estás levantando el entorno desde cero para pruebas:

1. Accede a tu contenedor de MySQL o instancia local.
2. Ejecuta el archivo de volcado `dump_ventas_td_angeles.sql` (o el script DDL/DML correspondiente a tu proyecto) para crear las tablas e insertar los registros de prueba.

## 14. Ejecución manual desde cero
Sigue estos pasos enumerados para configurar la sincronización de tu proyecto:

1. **Crear el Origen (Source):**
   * En la UI de Airbyte, ve a *Sources* > *New Source*.
   * Selecciona **MySQL**.
   * Ingresa las credenciales (Host, Puerto 3306, Usuario, Contraseña y nombre de la BD).
   * Configura el método de replicación (estándar o CDC si habilitaste los binlogs).


![Configuración Source MySQL](assets/airbyte_source.png)

2. **Crear el Destino (Destination):**
   * Ve a *Destinations* > *New Destination*.
   * Selecciona **PostgreSQL**.
   * Ingresa credenciales (Host, Puerto 5432, Usuario, Contraseña, BD: `dw_td_angeles`).
   * Define el esquema por defecto, por ejemplo: `airbyte_raw`.

*(Inserta aquí captura del formulario de conexión al Destination Postgres)*

![Configuración Destination Postgres](assets/airbyte_destination.png)

3. **Crear la Conexión:**
   * Ve a *Connections* > *New Connection*.
   * Selecciona el Source (MySQL) y el Destination (PostgreSQL) recién creados.
   * Selecciona los *Streams* (tablas) que deseas sincronizar: `ventas`, `asesores`, `pdv`, `oficinas`, `metas`.
   * Define el modo de sincronización: **Incremental | Append** (recomendado para ventas) o **Full Refresh | Overwrite** (recomendado para dimensiones pequeñas como oficinas).

*(Inserta aquí captura de la selección de tablas/streams en Airbyte)*

![Configuración de la Conexión](assets/airbyte_connection.png)

4. **Ejecutar la Sincronización:**
   * Haz clic en **Sync Now**.
   * Espera a que el log muestre el estado de *Completed*.

![Sync Exitoso](assets/airbyte_success.png)

## 15. Cómo validar que quedó operativo
1. Abre **DBeaver** y conéctate a tu base de datos **PostgreSQL**.
2. Navega al esquema configurado (ej: `airbyte_raw`).
3. Comprueba que las tablas existan. Normalmente, Airbyte las crea con un prefijo o como tablas crudas (ej. `_airbyte_raw_ventas`).
4. Haz un `SELECT COUNT(*)` y compáralo con la tabla de origen en MySQL para asegurar que no hubo pérdida de datos.

## 16. Flujo recomendado de migración
El ciclo de vida del dato (Data Pipeline) que se recomienda ejecutar en el día a día es el siguiente:

1. **(Airbyte) Ingesta Cruda:** MySQL -> PostgreSQL (Esquema `raw`).
2. **(dbt) Staging:** Limpieza de nulos y casteo de tipos (ej. solventar la sincronización de fechas y zonas horarias entre MySQL y Postgres) -> Esquema `staging`.
3. **(dbt) Marts:** Creación del modelo en estrella (Dimensiones y tabla de Hechos con cálculo de S/.220 para asesores y S/.160 para PDV) -> Esquema `dw_marts`.
4. **(Power BI) Consumo:** Lectura directa del esquema `dw_marts`.

## 17. Integración con dbt
Una vez que Airbyte finaliza su trabajo, `dbt` toma el control. Para que dbt reconozca los datos de Airbyte, se definen como `sources` en el archivo `src_td_angeles.yml`:

```yaml
version: 2

sources:
  - name: airbyte_raw
    schema: public
    tables:
      - name: ventas
      - name: vendedores
      - name: pdv
```

Luego, en los modelos de la capa Silver (ej: `stg_ventas.sql`), se extraen con la sintaxis:
`SELECT * FROM {{ source('airbyte_raw', 'ventas') }}`

## 18. Limitaciones actuales del proyecto
Según los hallazgos en las sesiones de desarrollo, identificamos las siguientes restricciones:

1. **Procesamiento acoplado al Host:** La ejecución de Airbyte y los comandos `dbt run` dependen de los recursos y la activación manual desde la máquina local o servidor host. Si la terminal se cierra, no hay automatización nativa.
2. **Sincronización de Fechas:** Hubo un grado de complejidad al sincronizar los formatos de fecha (`DATETIME` vs `TIMESTAMP`) entre MySQL y Postgres, lo que requirió tratamiento adicional en los scripts de dbt.
3. **Falta de test automáticos:** Aunque se hicieron pruebas genéricas, queda pendiente optimizar la ejecución de `dbt test` para que prevenga que datos corruptos lleguen al Dashboard.

## 19. Próximos pasos sugeridos
* **Implementar un Orquestador:** Integrar Apache Airflow o Prefect para programar el pipeline completo (gatillar `dbt run` automáticamente justo después de que Airbyte termine su sincronización exitosamente).
* **Mejorar las estrategias incrementales:** Configurar modelos incrementales en dbt para que no reprocese los históricos de ventas que ya están limpios y cargados en el DataMart.
* **Alertas:** Configurar notificaciones (vía Slack o correo) si falla una extracción en Airbyte o un test en dbt.

## 20. Referencias
* [Documentación oficial de Airbyte](https://docs.airbyte.com/)
* [Conector Airbyte MySQL Source](https://docs.airbyte.com/integrations/sources/mysql)
* [Conector Airbyte Postgres Destination](https://docs.airbyte.com/integrations/destinations/postgres)
* [Documentación oficial de dbt](https://docs.getdbt.com/)
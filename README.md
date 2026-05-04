# 📦 Pipeline ETL – TyG DataMart

Documentación del proceso de extracción, transformación y carga (ETL) desde el entorno transaccional hacia el entorno de Business Intelligence, con visualización final en Power BI.

---

## 2. Extracción y Carga (Staging)

Mueve los datos desde el entorno de producción al entorno de BI para su procesamiento.

```bash
# Exportar datos desde el contenedor transaccional
docker exec -e MYSQL_PWD=root tyg-oltp-container mysqldump -u root bd_transaccional > export_tyg_oltp.sql

# Crear la base de datos espejo en el contenedor de BI
docker exec -i -e MYSQL_PWD=root tyg-bi-container mysql -u root -e "CREATE DATABASE IF NOT EXISTS bd_transaccional;"

# Importar los datos al contenedor de BI
docker exec -i -e MYSQL_PWD=root tyg-bi-container mysql -u root bd_transaccional < export_tyg_oltp.sql
```

---

## 3. Configuración del Data Mart

Prepara el entorno analítico con los scripts de estructura y lógica de negocio.

```bash
# Copiar scripts al contenedor
docker cp ./mysql-bi/init/1_dm_tyg.sql tyg-bi-container:/tmp/1_dm_tyg.sql
docker cp ./mysql-bi/init/2_G_pasos_tyg.sql tyg-bi-container:/tmp/2_G_pasos_tyg.sql
docker cp ./mysql-bi/init/3_poblar_tyg.sql tyg-bi-container:/tmp/3_poblar_tyg.sql

# Crear estructura del Data Mart (Modelo Constelación)
docker exec -e MYSQL_PWD=root tyg-bi-container sh -c "mysql -u root < /tmp/1_dm_tyg.sql"

# Sincronizar Collation (Crítico para evitar errores de comparación de texto)
docker exec -e MYSQL_PWD=root tyg-bi-container mysql -u root -e "
  ALTER DATABASE tyg_datamart CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  ALTER TABLE tyg_datamart.dim_tiempo      CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  ALTER TABLE tyg_datamart.dim_oficina     CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  ALTER TABLE tyg_datamart.dim_estado      CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  ALTER TABLE tyg_datamart.dim_asesor_pdv  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  ALTER TABLE tyg_datamart.hecho_ventas    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  ALTER TABLE tyg_datamart.hecho_inventario CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  ALTER TABLE tyg_datamart.hecho_canal     CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  ALTER TABLE tyg_datamart.hecho_desempeno CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
"

# Crear Vista G de transformación logística en la base espejo
docker exec -e MYSQL_PWD=root tyg-bi-container sh -c "mysql -u root bd_transaccional < /tmp/2_G_pasos_tyg.sql"
```

---

## 4. Ejecución del Proceso ETL

Puebla las tablas de hechos y dimensiones finales.

```bash
docker exec -e MYSQL_PWD=root tyg-bi-container sh -c "mysql -u root < /tmp/3_poblar_tyg.sql"
```

---

## 📊 Visualización de KPIs en Power BI

Conecta **Power BI Desktop** a la base de datos analítica con los siguientes parámetros:

| Parámetro      | Valor            |
|----------------|------------------|
| Servidor       | `localhost:33306` |
| Base de Datos  | `tyg_datamart`   |
| Usuario        | `root`           |
| Contraseña     | `root`           |

### Indicadores Implementados (KPIs)

El modelo permite el análisis de los siguientes puntos clave:

#### 1. 🛒 Ventas
- Tasa de Activación
- Ingresos Totales
- Contribución por Oficina

#### 2. 🚚 Logística
- Kits en Riesgo (> 90 días)
- Días de Inactividad
- Rotación de Lote

#### 3. 📡 Canales
- Mix de Canal (Directo vs PDV)
- Cumplimiento de Metas Mensuales

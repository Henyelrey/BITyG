# Comparativos: Ventas, Pedidos y Metas

Esta sección detalla la lógica analítica y el modelado de datos utilizado para contrastar el volumen de kits recibidos (pedidos de inventario), las ventas reales ejecutadas (salidas) y las metas de activación establecidas por DIRECTV para **T&D Angeles E.I.R.L.**

---

## 1. Contexto del nuevo modelo

En la arquitectura transaccional heredada (MySQL de la Unidad 1), los registros operaban en silos: se registraba el ingreso de mercadería (pedidos/recepción de kits) por un lado, y las ventas por el otro, haciendo complejo cruzar esta información con las **Metas Mensuales** que impone DIRECTV a cada oficina.

El **nuevo modelo dimensional** construido con dbt y alojado en PostgreSQL resuelve este problema integrando múltiples tablas de hechos (Fact Tables) conectadas mediante dimensiones conformadas (Conformed Dimensions). 

Este enfoque permite a la gerencia responder preguntas críticas en un solo panel:
* ¿Cuántos kits pedimos a central vs cuántos realmente hemos vendido? *(Rotación de inventario)*
* ¿Cuántos de los kits vendidos están realmente activos? *(Tasa de activación)*
* ¿A qué distancia está cada oficina de cumplir su meta mensual? *(Rendimiento geográfico)*

---

## 2. Relaciones sugeridas en Power BI

Para soportar los comparativos sin generar ambigüedades lógicas o "relaciones de muchos a muchos", el modelo semántico en Power BI se estructura como un **Esquema en Constelación (Constellation Schema)**, con las siguientes relaciones clave:

### Dimensiones Conformadas (Filtros Globales)
Ambas tablas de hechos comparten estas dimensiones, lo que permite cruzar datos de ventas y pedidos bajo el mismo contexto:
* `Dim_Tiempo` (1) ───> (*) `Fact_Ventas` (Vía `fecha_venta`)
* `Dim_Tiempo` (1) ───> (*) `Fact_Metas_Pedidos` (Vía `fecha_mes`)
* `Dim_Oficina` (1) ───> (*) `Fact_Ventas` (Vía `id_oficina`)
* `Dim_Oficina` (1) ───> (*) `Fact_Metas_Pedidos` (Vía `id_oficina`)

### Especificaciones de Relación
* **Cardinalidad:** Todas las relaciones son de `1 a Muchos (1:*)`.
* **Dirección del Filtro Cruzado:** Única (Desde la Dimensión hacia la tabla de Hechos).
* **Beneficio:** Al seleccionar "Juliaca" en la `Dim_Oficina` o "Mayo 2026" en la `Dim_Tiempo`, el modelo filtrará automáticamente tanto las ventas generadas como el pedido/meta de ese mes, permitiendo que las medidas DAX interactúen correctamente.

*(Inserta aquí una captura del diagrama de relaciones de Power BI enfocado en cómo se unen las tablas de Ventas y Metas)*

![Relaciones del Modelo Comparativo](assets/relaciones_modelo.png)

---

## 3. Medidas DAX (Comparativos)

Para explotar este modelo y construir los comparativos en el Dashboard, se crearon las siguientes medidas explícitas en lenguaje DAX. Estas métricas gestionan los indicadores de canal (Asesor vs PDV), estado de activación y brecha de metas.

### 3.1. Métricas Base de Volumen
```dax
// Total de Kits Pedidos/Recibidos en inventario
Total_Kits_Pedidos = SUM(Fact_Metas_Pedidos[kits_recibidos])

// Total de Kits Vendidos (Salidas)
Total_Kits_Vendidos = COUNTROWS(Fact_Ventas)

// Inventario Disponible (Kits en stock no vendidos)
Stock_Actual = [Total_Kits_Pedidos] - [Total_Kits_Vendidos]
```

### 3.2. Comparativo de Canal (Asesor vs PDV)
```dax
// Ventas exclusivas de canal Asesor Interno
Ventas_Canal_Asesor = 
CALCULATE(
    [Total_Kits_Vendidos],
    Dim_Canal[Tipo_Canal] = "Asesor"
)

// Ventas exclusivas de Puntos de Venta (PDV) externos
Ventas_Canal_PDV = 
CALCULATE(
    [Total_Kits_Vendidos],
    Dim_Canal[Tipo_Canal] = "PDV"
)
```

### 3.3. Comparativo de Activación y Metas
Estas son las medidas críticas que determinan si T&D Angeles recibirá los bonos e incentivos operativos de DIRECTV.

```dax
// Total de Kits que figuran como "Activos" en el sistema
Total_Activaciones = 
CALCULATE(
    [Total_Kits_Vendidos],
    Dim_Estado[Estado_Kit] = "Activo"
)

// Tasa de Activación (Activaciones reales vs Ventas totales)
Tasa_Conversion_Activacion = 
DIVIDE(
    [Total_Activaciones],
    [Total_Kits_Vendidos],
    0
)

// Brecha para alcanzar la Meta (¿Cuántas activaciones faltan?)
Brecha_Meta_Activacion = 
VAR MetaMensual = SUM(Fact_Metas_Pedidos[meta_activacion])
VAR Diferencia = MetaMensual - [Total_Activaciones]
RETURN 
    IF(Diferencia > 0, Diferencia, 0) // Si es 0 o negativo, la meta fue superada

// Semáforo de Cumplimiento (Para formato condicional en tablas/gráficos)
Semaforo_Cumplimiento = 
VAR Porcentaje = DIVIDE([Total_Activaciones], SUM(Fact_Metas_Pedidos[meta_activacion]), 0)
RETURN
    SWITCH(
        TRUE(),
        Porcentaje >= 1, "🟢 Meta Cumplida",
        Porcentaje >= 0.8, "🟡 En Riesgo",
        "🔴 Crítico"
    )
```

### 3.4. Análisis de Ingresos por Precios Diferenciados
Basado en las reglas de negocio heredadas de la Unidad 1 (S/. 220 Asesor y S/. 160 PDV).

```dax
// Ingreso Monetario Total
Ingreso_Total_Soles = SUM(Fact_Ventas[monto_ingreso])

// Ticket Promedio de Venta
Ticket_Promedio = 
DIVIDE(
    [Ingreso_Total_Soles],
    [Total_Kits_Vendidos],
    0
)
```

---

## 4. Visualización Recomendada para los Comparativos

Para que los usuarios finales de T&D Angeles puedan interpretar estas medidas DAX eficazmente, se implementaron los siguientes elementos visuales en el reporte final:

1. **Gráfico de Medidor (Gauge Chart):** * **Valor:** `[Total_Activaciones]`
   * **Destino/Meta:** `SUM(Fact_Metas_Pedidos[meta_activacion])`
   * *Objetivo:* Ver de un vistazo el avance de cada oficina hacia su meta mensual.
2. **Gráfico de Barras Agrupadas:** * **Eje X:** `Dim_Oficina[Nombre_Oficina]`
   * **Valores:** `[Ventas_Canal_Asesor]` vs `[Ventas_Canal_PDV]`
   * *Objetivo:* Comparar qué fuerza de ventas domina en cada región.
3. **Matriz (Tabla Pivot):** * Mostrando Oficinas en filas, y usando la métrica `[Semaforo_Cumplimiento]` para resaltar automáticamente con colores el estado operativo.
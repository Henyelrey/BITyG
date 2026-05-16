FROM python:3.12-slim

WORKDIR /app

# Dependencias del sistema
RUN apt-get update && apt-get install -y \
    default-libmysqlclient-dev \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copiar requirements primero para aprovechar caché de Docker
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código ETL
COPY . /app/etl/

# DBT profiles se montan como volumen (./dbt_tyg)
ENV DBT_PROFILES_DIR=/app/dbt_tyg

# Punto de entrada
CMD ["python", "/app/etl/main.py"]

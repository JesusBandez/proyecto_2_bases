#!/bin/bash
# Copyright (c) 2023, Nestor Gonzalez, Jesus Bandez
# PostgreSQL psql runner script for OS X, Linux

# Carpeta que contiene los archivos CSV en github
folder="https://raw.githubusercontent.com/JesusBandez/proyecto_2_bases/master/CSVs/"

# Lista de nombres de archivos CSV
files=(
    "filtered_data_cities.csv"
    "filtered_data_names.csv"
    "items.csv"
    "marcas.csv"
    "names.csv"
    "phone_numbers.csv"
    "streets.csv"
)

# Descargar cada archivo CSV con wget si no existe en el directorio
for file in "${files[@]}"
do
    if [ -e CSVs/${file} ];
    then
        echo "El archivo ${file} ya se encuentra descargado"
    else wget -P "CSVs" "${folder}${file}"
    fi
done

# Pedir el nombre de usuario que se usara para interactuar con la base
echo -n "Username [postgres]: "
read USERNAME

if [ "$USERNAME" = "" ];
then
    USERNAME="postgres"
fi

echo -n "Database to create: "
read DATABASE

while [ "$DATABASE" = "" ];
do
    echo "Debe indicar el nombre de la DATABASE a crear"
    echo -n "Database: "
    read DATABASE
done

echo -n "Server [localhost]: "
read SERVER

if [ "$SERVER" = "" ];
then
    SERVER="localhost"
fi

echo -n "Port [5432]: "
read PORT

if [ "$PORT" = "" ];
then
    PORT="5432"
fi

createdb -h $SERVER -p $PORT -U $USERNAME $DATABASE
psql -h $SERVER -p $PORT -U $USERNAME $DATABASE -f "create_tables.sql" -f "synthetic_data.sql"
RET=$?

if [ "$RET" != "0" ];
then
    echo
    echo -n "Press <return> to continue..."
    read dummy
fi

exit $RET

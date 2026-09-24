#!/bin/sh
# Uruchomienie wszystkich uslug PROD z docelowa konfiguracja HTTPS.
set -eu

cd -- "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if [ ! -f .env.prod ]; then
    echo 'BLAD: Brak .env.prod w katalogu skryptu.' >&2
    exit 1
fi

compose() {
    docker compose --project-name odnrewer-pl-prod --env-file .env.prod \
        -f compose.yaml -f compose.prod.yaml "$@"
}

echo 'Sprawdzanie konfiguracji PROD...'
compose config --quiet

echo 'Uruchamianie uslug PROD (HTTPS)...'
compose up -d --wait --wait-timeout 300
compose ps

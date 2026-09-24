#!/bin/sh
# PROD: sprawdz konfiguracje Nginx i zrestartuj tylko dzialajace proxy.
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

echo 'Sprawdzanie konfiguracji Nginx PROD...'
compose exec -T proxy nginx -t

echo 'Restart proxy PROD...'
compose restart --no-deps proxy
compose ps proxy

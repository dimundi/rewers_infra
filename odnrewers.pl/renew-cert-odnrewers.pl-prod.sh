#!/bin/sh
# PROD: odnowienie tylko certyfikatu odnrewers.pl (wraz z www).
set -eu
cd -- "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
case "${1:-}" in
    '') ;;
    --dry-run) ;;
    *) echo 'Uzycie: sh renew-cert-odnrewers.pl-prod.sh [--dry-run]' >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || exit 2
for required in .env.prod compose.yaml compose.prod.yaml; do
    [ -f "$required" ] || { echo "Brak pliku: $required" >&2; exit 1; }
done
for directory in certbot/conf certbot/www; do
    [ -d "$directory" ] || { echo "Brak katalogu: $directory" >&2; exit 1; }
done

# Certbot korzysta ze wspolnego magazynu: poczekaj na zwolnienie blokady.
# Oddzielne harmonogramy i --cert-name izoluja wyniki odnowienia domen.
exec 9>certbot/renew-prod.lock
flock -w 600 9 || { echo 'Przekroczono czas oczekiwania na Certbot.' >&2; exit 1; }

docker run --rm \
    --mount "type=bind,source=$PWD/certbot/conf,target=/etc/letsencrypt" \
    --mount "type=bind,source=$PWD/certbot/www,target=/var/www/certbot" \
    certbot/certbot:v5.8.0 renew --cert-name odnrewers.pl \
    --non-interactive --no-random-sleep-on-renew --verbose --webroot -w /var/www/certbot "$@"

if [ "${1:-}" != '--dry-run' ]; then
    # Reload rowniez po sprawdzeniu bez odnowienia: ponawia ewentualny blad reloadu.
    docker compose --project-name odnrewer-pl-prod --env-file .env.prod \
        -f compose.yaml -f compose.prod.yaml exec -T proxy nginx -t
    docker compose --project-name odnrewer-pl-prod --env-file .env.prod \
        -f compose.yaml -f compose.prod.yaml exec -T proxy nginx -s reload
fi

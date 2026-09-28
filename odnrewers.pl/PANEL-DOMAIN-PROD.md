# Przeniesienie panelu PROD na panel.odnrewers.pl

Nowy panel działa pod `https://panel.odnrewers.pl/`. Stare adresy
`https://odnrewers.pl/szkolenia/...` zwracają tymczasowo 302 na tę samą
ścieżkę bez `/szkolenia`, z zachowaniem parametrów URL. Przykład:
`/szkolenia/kursy/106/1?widok=certyfikat` →
`https://panel.odnrewers.pl/kursy/106/1?widok=certyfikat`.
Adresy `/kupon/...` z domeny głównej przekierowują na identyczną ścieżkę
panelu, zachowując kod kuponu i parametry URL.
Adres `/ankieta` przekierowuje na `https://panel.odnrewers.pl/ankieta/`,
a `/ankieta/...` na identyczną ścieżkę panelu. Oba przekierowania zwracają
302 i zachowują parametry URL.

Zmiany dotyczą PROD. Panel DEV nadal działa pod `/szkolenia/`. Nowy build
PROD projektu `kursypanel` ma zasoby od `/` i musi trafić do katalogu
`PROD_PANEL_BUILD_DIR` z `.env.prod` na serwerze.

## Kolejność wdrożenia

Pracuj jako użytkownik `docker` w `/home/docker/odnrewers`. Wysyłaj pliki
przez SFTP, zachowując ścieżki z tego repozytorium.

1. Sprawdź, czy rekord A `panel.odnrewers.pl` wskazuje serwer PROD.
   Wyślij **tylko** `nginx/prod/panel-acme-prod.conf` i przeładuj działające
   proxy z obecną konfiguracją. Ten plik obsługuje wyzwania HTTP-01 bez
   certyfikatu nowej subdomeny.

   ```sh
   cd /home/docker/odnrewers
   docker compose --project-name odnrewer-pl-prod --env-file .env.prod -f compose.yaml -f compose.prod.yaml exec -T proxy nginx -t
   docker compose --project-name odnrewer-pl-prod --env-file .env.prod -f compose.yaml -f compose.prod.yaml exec -T proxy nginx -s reload
   ```

2. Wystaw osobny certyfikat. Zastąp adres e-mail kontaktem do powiadomień
   Let's Encrypt. Po udanym poleceniu sprawdź obecność
   `certbot/conf/live/panel.odnrewers.pl/fullchain.pem` i `privkey.pem`.

   ```sh
   flock -w 600 certbot/renew-prod.lock docker run --rm \
     --mount "type=bind,source=$PWD/certbot/conf,target=/etc/letsencrypt" \
     --mount "type=bind,source=$PWD/certbot/www,target=/var/www/certbot" \
     certbot/certbot:v5.8.0 certonly --webroot -w /var/www/certbot \
     --cert-name panel.odnrewers.pl -d panel.odnrewers.pl \
     --non-interactive --agree-tos --email 'WPISZ-ADRES-EMAIL'
   ```

3. Zbuduj `kursypanel` poleceniem `npm run build` i wyślij zawartość
   katalogu `build/` do katalogu wskazanego przez `PROD_PANEL_BUILD_DIR`.
   Wyślij pliki `static/` przed `index.html`.

4. Wyślij `compose.prod.yaml`, `panel/prod/panel-prod.conf` oraz
   `nginx/prod/proxy-prod.conf`. Certyfikat z kroku 2 musi już istnieć.
   Włącz nową konfigurację panelu i sprawdź oba Nginxy przed przeładowaniem
   publicznego proxy:

   ```sh
   docker compose --project-name odnrewer-pl-prod --env-file .env.prod -f compose.yaml -f compose.prod.yaml config --quiet
   docker compose --project-name odnrewer-pl-prod --env-file .env.prod -f compose.yaml -f compose.prod.yaml exec -T panel nginx -t
   docker compose --project-name odnrewer-pl-prod --env-file .env.prod -f compose.yaml -f compose.prod.yaml exec -T panel nginx -s reload
   docker compose --project-name odnrewer-pl-prod --env-file .env.prod -f compose.yaml -f compose.prod.yaml up -d --no-deps panel
   docker compose --project-name odnrewer-pl-prod --env-file .env.prod -f compose.yaml -f compose.prod.yaml exec -T proxy nginx -t
   docker compose --project-name odnrewer-pl-prod --env-file .env.prod -f compose.yaml -f compose.prod.yaml exec -T proxy nginx -s reload
   ```

5. Sprawdź odpowiedzi z serwera i przejdź w przeglądarce przez logowanie,
   listę kursów oraz certyfikat:

   ```sh
   curl -I https://panel.odnrewers.pl/
   curl -I https://panel.odnrewers.pl/kursy
   curl -I 'https://odnrewers.pl/szkolenia/kursy/106/1?widok=certyfikat'
   curl -I 'https://odnrewers.pl/szkolenia?test=1'
   curl -I 'https://odnrewers.pl/kupon/dshfnksdnfd/?test=1'
   curl -I 'https://odnrewers.pl/ankieta?test=1'
   curl -I 'https://odnrewers.pl/ankieta/?test=1'
   ```

   Pięć ostatnich żądań ma zwrócić 302 z odpowiednim nagłówkiem
   `Location`. Po zmianie domeny przeglądarka ma osobny magazyn sesji,
   dlatego użytkownik może musieć zalogować się ponownie.

6. Wyślij `renew-cert-panel.odnrewers.pl-prod.sh` oraz dwa pliki
   `systemd/renew-cert-panel.odnrewers.pl-prod.*`. Sprawdź odnowienie i
   uruchom niezależny timer:

   ```sh
   sh renew-cert-panel.odnrewers.pl-prod.sh --dry-run
   sudo install -m 644 systemd/renew-cert-panel.odnrewers.pl-prod.service systemd/renew-cert-panel.odnrewers.pl-prod.timer /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now renew-cert-panel.odnrewers.pl-prod.timer
   systemctl list-timers --all 'renew-cert-*-prod.timer'
   ```

   Jeśli użytkownik `docker` nie ma `sudo`, wykonaj polecenia `sudo` z konta
   administracyjnego, zachowując podane ścieżki absolutne do plików.

Po sprawdzeniu przekierowań można zmienić status 302 na trwały 301 w
`nginx/prod/proxy-prod.conf`. Starsze linki generowane przez API (e-mail,
powrót z płatności) nadal działają dzięki przekierowaniu i można je
zaktualizować osobno.

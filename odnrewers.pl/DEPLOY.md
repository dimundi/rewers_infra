# Wysyłka PROD przez SFTP

Pliki przesyłamy ręcznie przez WinSCP (SFTP) do `/home/docker/odnrewers/`. Serwer nie wymaga klonowania repozytorium.

Połączenie: host `51.68.147.102`, port `22`, użytkownik `docker`. Klucz prywatny pozostaje na komputerze; nie przesyłamy go na serwer.

## Konfiguracja Dockera

Z katalogu `odnrewers.pl` prześlij poniższe pliki, zachowując ścieżki względem katalogu docelowego:

- `compose.yaml`
- `compose.prod.yaml`
- `.env.prod.example`
- `nginx/prod/proxy-prod.conf`
- `panel/prod/panel-prod.conf`
- `wordpress/prod/php.ini`

Jeżeli wcześniej przesłano `nginx/prod/default.conf` lub `panel/prod/default.conf`, usuń te stare pliki na serwerze po skopiowaniu nowych nazw. Nie pozostawiaj obu wersji: Nginx wczytuje wszystkie pliki `*.conf` w montowanym katalogu.

Nie przesyłamy plików DEV, linkowanych źródeł panelu ani plików BAT. Sam transfer nie uruchamia kontenerów.

## Panel i WordPress

| Pliki | Katalog docelowy |
| --- | --- |
| Zawartość gotowego buildu panelu PROD (`index.html`, `static/` itd.) | `/home/docker/odnrewers/panel/build-prod/` |
| Instalator PHP i archiwum WordPressa | `/home/docker/odnrewers/wordpress/prod/www/` |

Utwórz katalogi docelowe przed wysyłką. W `.env.prod` na serwerze ustaw `PROD_PANEL_BUILD_DIR=./panel/build-prod`. Build panelu musi mieć produkcyjny adres API. WordPressa odtwarzamy instalatorem do osobnej bazy PROD; nie kopiujemy `wp-config.php` z DEV. Katalog WWW musi być zapisywalny dla użytkownika `www-data` kontenera (UID 33).

Rzeczywisty `.env.prod`, certyfikaty i dane baz przygotowujemy oddzielnie. Start HTTP opisano poniżej; docelowe HTTPS wymaga obu wystawionych certyfikatów w `certbot/conf`.

## Pierwsze uruchomienie PROD przez HTTP

Prześlij także `compose.prod-http.yaml` i `nginx/prod-http/proxy-prod-http.conf`, zachowując katalogi. Nie kopiuj konfiguracji HTTP do `nginx/prod/` — jest montowana osobno zamiast docelowej konfiguracji HTTPS.

Na serwerze jako `docker`, po przygotowaniu `.env.prod` i buildu panelu:

```bash
cd /home/docker/odnrewers
mkdir -p certbot/conf certbot/www wordpress/prod/www
chmod 600 .env.prod
docker compose --env-file .env.prod -f compose.yaml -f compose.prod.yaml -f compose.prod-http.yaml config --quiet
docker compose --env-file .env.prod -f compose.yaml -f compose.prod.yaml -f compose.prod-http.yaml up -d
docker compose --env-file .env.prod -f compose.yaml -f compose.prod.yaml -f compose.prod-http.yaml ps
curl -i http://127.0.0.1/healthz
curl -I -H 'Host: odnrewers.pl' http://127.0.0.1/szkolenia/
```

Proxy publikuje port 80, obsługuje ACME dla czterech nazw i używa tych samych danych PROD. Pozostałe kontenery nie publikują portów. Reguły sieciowe serwera/OVH muszą dopuszczać TCP 80. Przed zmianą DNS sprawdź panel poleceniem z nagłówkiem Host; wejście po samym IP poza `/healthz` zwraca 404.

WordPress wymaga osobnego odtworzenia z instalatora i uprawnień zapisu UID 33 do katalogu WWW. Nie loguj się do aplikacji ani nie przesyłaj haseł instalatora przez publiczne HTTP; ten etap służy uruchomieniu proxy i wystawieniu certyfikatów. Instalację WordPressa dokończ po włączeniu HTTPS.

Konfiguracja HTTP wymaga Compose 2.24.4 lub nowszego (`!override`). Po sprawdzeniu HTTP przełącz DNS i wystaw dwa certyfikaty. Następnie przejdź na HTTPS według instrukcji poniżej.

## Przejście na HTTPS

Prześlij aktualny `compose.prod.yaml` i `nginx/prod/proxy-prod.conf`. W `nginx/prod/` pozostaw tylko aktualny plik proxy. Wymagane są oba certyfikaty w `certbot/conf/live/odnrewers.pl/` oraz `certbot/conf/live/rewers.edu.pl/`, wraz z pełną strukturą Certbota (w tym `archive`).

Na serwerze:

```bash
cd /home/docker/odnrewers
docker compose --env-file .env.prod -f compose.yaml -f compose.prod.yaml run --rm --no-deps proxy nginx -t
docker compose --env-file .env.prod -f compose.yaml -f compose.prod.yaml up -d --no-deps proxy
curl -I https://odnrewers.pl/szkolenia/
curl -I https://rewers.edu.pl/szkolenia/
```

Polecenie `up` wykonaj tylko po udanym teście Nginx. Nie dodawaj `compose.prod-http.yaml` przy uruchamianiu HTTPS. Porty 80 i 443 muszą być dostępne publicznie. ACME pozostaje na porcie 80. Automatyczne odnawianie wymaga aktywowania dwóch timerów opisanych poniżej. WordPress musi rozpoznawać nagłówek `X-Forwarded-Proto: https`.

## Uruchamianie PROD skryptem na serwerze

Prześlij `start-prod.sh` do `/home/docker/odnrewers/`, obok plików Compose. Uruchom jako użytkownik `docker`:

```bash
cd /home/docker/odnrewers
sh start-prod.sh
```

Skrypt sprawdza konfigurację, uruchamia wszystkie usługi PROD z HTTPS i czeka do 300 sekund na ich gotowość, po czym pokazuje stan. Używa wyłącznie `.env.prod`, `compose.yaml` i `compose.prod.yaml`, z projektem `odnrewer-pl-prod`. Wymaga wcześniej przygotowanych certyfikatów i plików aplikacji. Nie wysyła plików ani nie buduje panelu. Polecenie `up` stosuje zmiany Compose; sama edycja zamontowanej konfiguracji Nginx wymaga osobno jej sprawdzenia i przeładowania proxy.

## Automatyczne odnawianie certyfikatów PROD — dwie osobne procedury

Każda domena ma osobny skrypt, usługę i timer. `--cert-name` ogranicza odnowienie do jednego certyfikatu (domena wraz z www). Błąd odnowienia jednej domeny nie zatrzymuje harmonogramu drugiej. Nie ma nadrzędnego skryptu uruchamiającego obie procedury.

Prześlij oba skrypty `renew-cert-*-prod.sh` do `/home/docker/odnrewers/` i cztery pliki `systemd/renew-cert-*-prod.*` do podkatalogu `systemd/`.

### odnrewers.pl + www.odnrewers.pl

Test jako `docker` (testowe odnowienie nie zastępuje certyfikatu produkcyjnego):

```bash
cd /home/docker/odnrewers
sh renew-cert-odnrewers.pl-prod.sh --dry-run
```

Po udanym teście, jako `debian`:

```bash
sudo install -m 644 /home/docker/odnrewers/systemd/renew-cert-odnrewers.pl-prod.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now renew-cert-odnrewers.pl-prod.timer
sudo systemctl start renew-cert-odnrewers.pl-prod.service
sudo journalctl -u renew-cert-odnrewers.pl-prod.service -n 50 --no-pager
```

### rewers.edu.pl + www.rewers.edu.pl

Test jako `docker`:

```bash
cd /home/docker/odnrewers
sh renew-cert-rewers.edu.pl-prod.sh --dry-run
```

Po udanym teście, jako `debian`:

```bash
sudo install -m 644 /home/docker/odnrewers/systemd/renew-cert-rewers.edu.pl-prod.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now renew-cert-rewers.edu.pl-prod.timer
sudo systemctl start renew-cert-rewers.edu.pl-prod.service
sudo journalctl -u renew-cert-rewers.edu.pl-prod.service -n 50 --no-pager
```

### Kontrola i zasady działania

```bash
systemctl list-timers --all 'renew-cert-*-prod.timer'
```

Pierwszy timer działa o 00:00/12:00, drugi o 02:00/14:00 czasu serwera, z losowym opóźnieniem do 15 minut. `Persistent=true` nadrabia pominięte uruchomienie po włączeniu serwera. Samo przesłanie plików nie aktywuje timerów.

Certbot odnawia wybrany certyfikat tylko gdy jest to potrzebne. Skrypty wyłączają jego dodatkowe losowe oczekiwanie (`--no-random-sleep-on-renew`), ponieważ harmonogram ma własne losowe opóźnienie. Opcja `--verbose` pokazuje postęp i ułatwia diagnostykę testu. Po sukcesie sprawdzenia/odnowienia skrypt sprawdza Nginx i przeładowuje proxy, bez restartu kontenera. Błąd Certbota kończy tylko daną procedurę, bez przeładowania. Test `--dry-run` nie przeładowuje proxy. Test konfiguracji Nginx wykonywany jest po odnowieniu, aby problem drugiego certyfikatu nie blokował samego odnowienia pierwszego.

Obie procedury nadal używają wspólnego magazynu `certbot/conf` i jednego proxy Nginx. Blokada z oczekiwaniem do 10 minut zapobiega równoczesnej pracy Certbota na tym magazynie. Nie ma pełnej izolacji serwera: błąd wspólnej konfiguracji Nginx może zablokować przeładowanie, ale skrypt nie zatrzyma działającego proxy. Port 80 i `certbot/www` muszą pozostać dostępne do walidacji ACME. Usługi działają jako `docker`; wyniki są w dzienniku systemd. Powiadomienia o błędach nie są skonfigurowane.

Jeśli poprzedni wspólny timer został już zainstalowany, wyłącz go przed aktywacją nowych (jako `debian`):

```bash
sudo systemctl disable --now odnrewer-pl-renew-certs.timer
```

Jeżeli wspólna usługa jest w trakcie odnawiania, poczekaj na jej zakończenie. Usuń stare pliki `renew-certs-prod.sh` i `systemd/odnrewer-pl-renew-certs.*` z katalogu wdrożenia; nie są już używane. Nie usuwaj magazynu certyfikatów.

## Blokady plików WordPressa w proxy PROD

`nginx/prod/proxy-prod.conf` blokuje PHP (także phtml/phar i PATH_INFO) w `wp-content/uploads`, pliki ukryte poza `.well-known`, konfigurację `wp-config.php`, logi, zrzuty SQL, typowe kopie edytorów i pozostałości Duplicatora oraz wybrane katalogi kopii. Ukrywa również nagłówek `X-Powered-By` z odpowiedzi aplikacji. Reguły nie blokują zwykłych plików ZIP w uploads ani REST API, wp-admin i formularzy. Panel `/szkolenia/` zachowuje osobny routing.

Po przesłaniu pliku na serwer sprawdź i przeładuj proxy jako `docker`:

```bash
cd /home/docker/odnrewers
docker compose --env-file .env.prod -f compose.yaml -f compose.prod.yaml exec -T proxy nginx -t
# Tylko po udanym sprawdzeniu:
docker compose --env-file .env.prod -f compose.yaml -f compose.prod.yaml exec -T proxy nginx -s reload
```

Blokady nie usuwają plików z dysku i nie zastępują usunięcia instalatora/archiwum. Archiwa o dowolnych nazwach wymagają osobnego sprawdzenia i usunięcia; proxy nie blokuje wszystkich ZIP, ponieważ mogą być materiałami do pobrania. Wewnętrzne ustawienia WordPressa, aktualizacje, konta, 2FA i kopie poza serwerem wymagają osobnej weryfikacji.

## Restart proxy PROD

Po przesłaniu zmienionej konfiguracji Nginx możesz użyć `restart-proxy-prod.sh` (prześlij go obok Compose):

```bash
cd /home/docker/odnrewers
sh restart-proxy-prod.sh
```

Skrypt sprawdza konfigurację w działającym kontenerze i tylko po udanym teście restartuje usługę `proxy`. Błąd testu przerywa operację. Restart powoduje krótką przerwę w obsłudze ruchu; pozostałe kontenery działają dalej. Nie stosuje zmian portów, mountów ani innych ustawień Compose — te wymagają odtworzenia kontenera poleceniem `up -d`. Skrypt pokazuje stan kontenera, ale nie czeka na wynik healthchecku.

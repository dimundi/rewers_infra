# WordPress — instalator z archiwum

## Katalogi i kontenery

- `dev/www/`: pusty katalog na instalator PHP i archiwum DEV. Po instalacji zawiera pliki strony, w tym `wp-content` i `wp-config.php`.
- `prod/www/`: osobny katalog plików PROD.
- `dev/php.ini` i `prod/php.ini`: osobna konfiguracja PHP podłączana tylko do odczytu.
- `wordpress`: Apache + PHP 8.3 z rozszerzeniami oficjalnego obrazu WordPressa.
- `wordpress-db`: MariaDB 11.4, bez portu opublikowanego na hoście.

Celowo pominięto entrypoint inicjalizujący oficjalnego obrazu WordPressa. Kontener nie kopiuje rdzenia WordPressa ani nie tworzy `wp-config.php`; zrobi to dostarczony instalator. Nie uruchamiaj standardowej instalacji WordPressa przed odtworzeniem archiwum.

Foldery `www` są wykluczone z Gita. Po sklonowaniu repozytorium trzeba utworzyć je ponownie. Na Linuksie katalog wybranego środowiska musi być zapisywalny przez użytkownika `www-data` kontenera (UID 33); dotyczy to także późniejszego wgrywania mediów i aktualizacji.

## DEV — instalacja

1. Skopiuj instalator PHP i jego archiwum do `wordpress/dev/www/`.
2. Uruchom `start-dev.bat` w katalogu serwera. Skrypt uruchomi także WordPressa i bazę. Pierwszy start może potrwać dłużej z powodu pobierania obrazów i inicjalizacji bazy.
3. Otwórz `http://localhost:8080/NAZWA-INSTALATORA.php`. Jeśli instalator nazywa się `installer.php`, użyj `http://localhost:8080/installer.php`. Przy innym `DEV_HTTP_PORT` zmień port w adresie.
4. W instalatorze podaj dane poniżej. Hasło odczytaj lokalnie z `.env.dev`.
5. Jako docelowy adres strony ustaw `http://localhost:8080` (lub właściwy port DEV). Instalator powinien wykonać migrację adresów w bazie z zachowaniem danych serializowanych.
6. Po zakończeniu użyj funkcji instalatora usuwającej archiwum i pliki instalacyjne.

| Pole instalatora DEV | Wartość |
| --- | --- |
| Serwer bazy | `wordpress-db` |
| Port bazy | `3306` |
| Nazwa bazy | Wartość `DEV_WP_DB_NAME` z `.env.dev` (domyślnie `wordpress_dev`) |
| Użytkownik | Wartość `DEV_WP_DB_USER` z `.env.dev` (domyślnie `wordpress_dev`) |
| Hasło | Wartość `DEV_WP_DB_PASSWORD` z `.env.dev` |

Używaj konta aplikacji, nie konta root. Dane bazy wpisane przez instalator trafiają do `wp-config.php`; zmienne `.env.dev` służą inicjalizacji MariaDB, a nie automatycznej zmianie tego pliku. Zmiana hasła w `.env.dev` po inicjalizacji wolumenu nie zmienia istniejącego hasła w bazie.

Panel pozostaje pod `/szkolenia/`. Reszta ruchu DEV trafia do WordPressa. Pusty katalog WWW może zwracać 403 przed skopiowaniem plików — nie oznacza to awarii kontenera.

## Izolacja DEV

WordPress DEV ma wyłącznie wewnętrzne sieci Dockera: nie ma bezpośredniego wyjścia do internetu. Zapobiega to wysyłaniu rzeczywistych maili, płatności i żądań do usług produkcyjnych z odtworzonej kopii. PHP `mail()` jest dodatkowo wyłączone przez ustawienie `sendmail_path`.

Konsekwencja: pobieranie wtyczek, sprawdzanie licencji i instalatory pobierające dane z internetu nie zadziałają bez osobno uzgodnionej konfiguracji dostępu. Przeglądarka użytkownika nadal może otwierać zewnętrzne linki i skrypty; przed testowaniem płatności ustaw sandbox w odtworzonej stronie. Nie podłączono jeszcze skrzynki przechwytującej maile.

## Odtworzenie na produkcji

Oba środowiska używają tych samych definicji usług i obrazów w `compose.yaml`. Produkcja ma własne bind mounty, bazę, hasła i sieci. WordPress PROD ma dodatkową sieć z wyjściem do internetu; baza pozostaje wyłącznie w sieci prywatnej.

Do przeniesienia działającej strony potrzebne są **pliki WWW i eksport bazy** (albo nowa kompletna paczka migracyjna). Samo odtworzenie kontenerów nie przenosi danych z komputera deweloperskiego.

1. Na serwerze odtwórz konfigurację i pusty katalog `wordpress/prod/www`.
2. Przygotuj `.env.prod` z osobnymi danymi `PROD_WP_DB_*` oraz buildem panelu PROD.
3. Ustal i skonfiguruj publiczny routing oraz HTTPS. Obecny `compose.prod.yaml` nadal nie publikuje portów.
4. Odtwórz stronę z paczki migracyjnej albo importuj eksport bazy i skopiuj pliki WWW.
5. Skonfiguruj `wp-config.php` dla bazy PROD (`wordpress-db:3306`, dane z `.env.prod`). Ustaw rzeczywisty adres strony i obsługę HTTPS za proxy. Nie kopiuj bez zmian konfiguracji DEV.
6. Na produkcji sprawdź adresy, logowanie, media i integracje, a następnie usuń pliki instalacyjne.

Przed migracją produkcyjną zapisz przetestowane digesty obrazów, aby odtworzyć dokładnie te same wersje, nawet jeśli tagi obrazów zostaną zaktualizowane.

## Trwałość danych

- Baza: wolumen `odnrewer-pl-dev_wordpress_db` lub `odnrewer-pl-prod_wordpress_db`.
- Pliki strony: odpowiedni folder `wordpress/dev/www` lub `wordpress/prod/www` na hoście.
- Odtworzenie kontenera oraz zwykłe `docker compose down` zachowują te dane. `down -v` usuwa wolumen bazy — nie używaj go do zwykłego restartu.
- Kopia bezpieczeństwa musi obejmować pliki WWW i logiczny eksport bazy. Bieżąca konfiguracja nie dodaje automatycznych backupów.

Konfiguracja została sprawdzona przez `docker compose config`. Nie uruchamiano nowego zestawu kontenerów ani nie testowano instalatora. Zgodność archiwum z PHP 8.3 i MariaDB 11.4 należy potwierdzić podczas instalacji DEV.

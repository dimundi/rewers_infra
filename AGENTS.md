# Zasady repozytorium infrastruktury

Konfigurację organizujemy w katalogach odpowiadających poszczególnym serwerom. Katalog `odnrewers.pl` dotyczy serwera tej domeny.

## Wyraźne rozdzielenie DEV i PROD

- Używaj nazw środowisk **DEV** i **PROD**. Nie używaj nazwy `local` zamiast `dev`.
- `compose.yaml` zawiera wyłącznie konfigurację wspólną, bez domyślnych połączeń do produkcji.
- `compose.dev.yaml` zawiera ustawienia DEV, a `compose.prod.yaml` ustawienia PROD. Uruchamiaj konfigurację wspólną razem z jawnym plikiem wybranego środowiska.
- Zmienne i sekrety przechowuj osobno w `.env.dev` i `.env.prod`. Pliki te muszą być wykluczone z Gita. W repozytorium przechowuj osobne wzory `.env.dev.example` i `.env.prod.example`, bez sekretów.
- Dla serwera `odnrewers.pl` stosuj nazwy projektów Docker Compose `odnrewer-pl-dev` i `odnrewer-pl-prod`. Dla kolejnych serwerów stosuj odrębne nazwy z jednoznacznym oznaczeniem środowiska.
- Kontenery, sieci, wolumeny, bazy danych, pliki aplikacji i dane dostępowe DEV oraz PROD muszą być rozdzielone. Nie stosuj wspólnych nazw zasobów ani wspólnych katalogów danych, które omijałyby izolację projektów Compose.
- DEV korzysta wyłącznie z danych testowych lub osobnej kopii danych. Nie może domyślnie łączyć się z produkcyjną bazą ani zapisywać do produkcyjnego magazynu plików.
- W DEV kieruj pocztę do skrzynki testowej i używaj sandboxa płatności. Rzeczywista wysyłka i rzeczywiste płatności należą do PROD.
- Adresy środowisk i routing wymagają osobnego ustalenia. Nie traktuj proponowanych wcześniej adresów i reguł jako zatwierdzonych.
- Przygotuj osobne, wyraźnie opisane polecenia lub skrypty uruchamiania DEV i PROD. Jawnie wskazuj projekt Compose, pliki konfiguracji i właściwy plik zmiennych środowiskowych.
- W dokumentacji, przykładach poleceń oraz skryptach jednoznacznie oznaczaj środowisko, którego dotyczy operacja.

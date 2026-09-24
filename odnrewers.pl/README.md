# Serwer odnrewers.pl

Serwer w OVHcloud Public Cloud, typ **b2-7**.

## Parametry

| Parametr | Wartość |
| --- | --- |
| Procesor | 2 vCPU |
| Pamięć RAM | 7 GB |
| Dysk | 50 GB SSD |
| Sieć publiczna | 250 Mbit/s gwarantowane |
| Sieć prywatna (vRack) | Do 300 Mbit/s |

Źródło parametrów: [cennik OVHcloud Public Cloud](https://www.ovhcloud.com/pl/public-cloud/prices/), sprawdzony 24 września 2026 r.

## Przeznaczenie

Serwer jest przeznaczony do uruchomienia:

- **Reverse proxy Nginx** — obsługa ruchu przychodzącego, certyfikatów HTTPS i kierowanie żądań do aplikacji.
- **Strony odnrewers.pl w WordPressie** — publiczna strona WWW.
- **Panelu szkoleniowego React** — aplikacja z projektu `kursypanel`, dostępna pod `/szkolenia/`.

Usługi będą uruchamiane w kontenerach Docker zarządzanych przez Docker Compose. Najpierw konfiguracja będzie przygotowana i sprawdzona lokalnie, a następnie wdrożona na serwerze.

Przygotowano konfigurację DEV dla proxy i panelu oraz oddzielny szkielet PROD. Dodano również WordPress/PHP oraz osobny kontener MariaDB; instalator i archiwum dostarcza użytkownik. Lokalizacja API szkoleń i jego bazy danych pozostaje do ustalenia.

## Dostęp do serwera produkcyjnego

Z serwerem produkcyjnym łączymy się przez SSH za pomocą klucza o nazwie `Kursy-SSH`.

## Źródła i kontener panelu szkoleniowego

Źródła panelu `kursypanel` znajdują się w linkowanym folderze. Kod aplikacji pozostaje poza repozytorium infrastruktury; nie kopiujemy go do tego repozytorium. Lokalny link `panel/sources` wskazuje na `D:\GIT\kursypanel` i jest wykluczony z Gita. DEV i PROD korzystają z tego samego kodu źródłowego, ale wymagają oddzielnych buildów i danych.

W pierwszym kroku przygotowujemy kontener panelu: Nginx serwujący gotowe, zbudowane pliki Reacta z katalogu `build`. Budowanie odbywa się poza kontenerem uruchomieniowym; kontener nie wymaga Node.js.

Buildy DEV i PROD przygotowujemy oddzielnie z konfiguracją odpowiedniego środowiska, ponieważ adres API jest zapisywany podczas budowania aplikacji.

WordPress ma osobną konfigurację i katalogi danych w `wordpress/`; instrukcja instalacji znajduje się w [wordpress/README.md](wordpress/README.md).

## Proxy Nginx i pliki konfiguracyjne

Reverse proxy działa na Nginx. Pliki konfiguracyjne Nginx przechowujemy w folderze `nginx/` tego katalogu serwera i podłączamy do kontenera przez bind mount w trybie tylko do odczytu. Konfiguracja pozostaje w repozytorium infrastruktury, poza obrazem kontenera.

Konfiguracje DEV i PROD muszą być wyraźnie rozdzielone. Właściwy plik Compose wskazuje pliki konfiguracyjne odpowiednie dla danego środowiska. Routing DEV dla panelu został zatwierdzony: `http://localhost:8080/szkolenia/`. Routing PROD oraz konfiguracja HTTPS pozostają do ustalenia.

## Pliki konfiguracji

| Plik lub katalog | Przeznaczenie |
| --- | --- |
| `compose.yaml` | Wspólne usługi `proxy`, `panel`, `wordpress`, `wordpress-db`, sieci i wolumen bazy |
| `compose.dev.yaml` | DEV: osobna sieć projektu, bind mount buildu DEV, port `127.0.0.1:8080` |
| `compose.prod.yaml` | Szkielet PROD: oddzielne mounty i sieć, bez publicznych portów |
| `.env.dev.example` | Wzór lokalnego `.env.dev` |
| `.env.prod.example` | Wzór produkcyjnego `.env.prod` |
| `nginx/dev/` i `panel/dev/` | Konfiguracja Nginx dla DEV |
| `nginx/prod/` i `panel/prod/` | Oddzielna konfiguracja Nginx dla PROD |

## DEV — przygotowanie buildu panelu

Źródła pozostają w linkowanym folderze projektu `kursypanel`. Kontener otrzymuje tylko folder wynikowy buildu przez bind mount. Nie wymaga to kopiowania źródeł do repozytorium ani tworzenia dowiązania w repozytorium: ścieżkę folderu lub istniejącego linku wskazuje `DEV_PANEL_BUILD_DIR`.

1. Przygotuj osobny build DEV w projekcie panelu. Przykładowa lokalizacja wyniku to `D:/GIT/kursypanel/build-dev`.
2. Build musi zawierać `index.html` i folder `static`, z adresem zasobów `/szkolenia` (ustawienie `PUBLIC_URL` przy budowaniu).
3. Podczas budowania ustaw wszystkie właściwe dla DEV zmienne aplikacji, w szczególności `REACT_APP_API_URL` i `REACT_APP_AUTH_URL`. Zwykłe `npm run build` w tym projekcie wczytuje `.env.production`, dlatego nie należy traktować tak powstałych plików jako buildu DEV bez jawnego ustawienia konfiguracji DEV.
4. Przy budowaniu można wskazać `BUILD_PATH=build-dev`, aby nie nadpisać buildu PROD. Każde środowisko musi mieć osobny katalog wynikowy.

Zmiana `.env.dev` infrastruktury nie zmienia adresów API zapisanych w JavaScript. Zmiana konfiguracji aplikacji wymaga nowego buildu Reacta. W bieżącym etapie API nie jest uruchamiane przez Compose; działanie logowania i danych wymaga dostępnego API DEV.

## DEV — konfiguracja i uruchomienie

Polecenia wykonuj w PowerShell, w katalogu tego serwera:

```powershell
cd D:\GIT\rewers_infra\odnrewers.pl
Copy-Item .env.dev.example .env.dev
```

Kopiowanie wzoru wykonaj tylko przy pierwszej konfiguracji; nie nadpisuj istniejącego `.env.dev`.
W `.env.dev` wpisz rzeczywistą ścieżkę do gotowego buildu DEV, używając ukośników `/`, na przykład:

```dotenv
DEV_PANEL_BUILD_DIR=D:/GIT/kursypanel/build-dev
DEV_HTTP_PORT=8080
```

Sprawdź konfigurację bez uruchamiania kontenerów:

```powershell
docker compose --project-name odnrewer-pl-dev --env-file .env.dev -f compose.yaml -f compose.dev.yaml config --quiet
```

Uruchom DEV:

```powershell
docker compose --project-name odnrewer-pl-dev --env-file .env.dev -f compose.yaml -f compose.dev.yaml up -d
```

Adres panelu: **http://localhost:8080/szkolenia/login**.
Nginx przekazuje `/szkolenia/` do panelu, a `/szkolenia` przekierowuje na `/szkolenia/`. Trasy Reacta obsługują odświeżanie strony. Brakujące zasoby statyczne zwracają 404. Pozostałe adresy, w tym `/`, trafiają do WordPressa. Przed skopiowaniem instalatora pusty katalog może zwracać 403.

Logi DEV:

```powershell
docker compose --project-name odnrewer-pl-dev --env-file .env.dev -f compose.yaml -f compose.dev.yaml logs --tail 100 -f
```

Zatrzymanie DEV:

```powershell
docker compose --project-name odnrewer-pl-dev --env-file .env.dev -f compose.yaml -f compose.dev.yaml down
```

Brak folderu buildu powoduje błąd montowania zamiast utworzenia pustego katalogu. Brak lub pusty `index.html` uniemożliwia start kontenera panelu. Obrazy mogą zostać pobrane przy pierwszym uruchomieniu. Po zmianie plików konfiguracji Nginx zrestartuj odpowiednie kontenery; sam bind mount nie powoduje automatycznego przeładowania konfiguracji.

## PROD — status przygotowania

PROD jest w przygotowaniu. Docelowy routing HTTPS i przekierowania domen zapisano w konfiguracji Nginx; szczegóły zawiera [PRODUCTION.md](PRODUCTION.md). Compose PROD publikuje porty 80/443 i montuje certyfikaty; start HTTPS wymaga obu wystawionych certyfikatów. Przed uruchomieniem trzeba przygotować HTTP do wydania certyfikatu, podłączyć HTTPS oraz przygotować dane WordPressa i build panelu PROD z docelowym API.

W `.env.prod` utworzonym z `.env.prod.example` należy wskazać `PROD_PANEL_BUILD_DIR` — osobny folder zawierający build PROD na serwerze. Nie używaj katalogu buildu DEV.

Walidacja konfiguracji PROD bez uruchamiania:

```bash
docker compose --project-name odnrewer-pl-prod --env-file .env.prod -f compose.yaml -f compose.prod.yaml config --quiet
```

Nie łącz plików `compose.dev.yaml` i `compose.prod.yaml` w jednym wywołaniu. Nazwy projektów rozdzielają sieci i kontenery. Pliki `.env.dev`, `.env.prod`, buildy, dane trwałe i certyfikaty pozostają poza Gitem.

## Weryfikacja przygotowanej konfiguracji

Sprawdzono oba zestawy poleceniem `docker compose config` z przykładowymi ścieżkami. Potwierdzono oddzielne sieci, mounty tylko do odczytu, port DEV ograniczony do localhost oraz brak publicznych portów PROD i kontenera panelu.

Nie uruchamiano kontenerów, nie budowano panelu ani nie wykonano testów HTTP lub `nginx -t`. Utworzono lokalne dowiązanie katalogowe `panel/sources` do `D:\GIT\kursypanel`. Gotowego buildu nie znaleziono; jego folder trzeba wskazać przed startem DEV.

## Organizacja proxy, panelu i linku do źródeł

- `nginx/dev/` i `nginx/prod/` zawierają wyłącznie konfigurację reverse proxy.
- `panel/dev/` i `panel/prod/` zawierają konfigurację serwera statycznych plików panelu. Jest to osobny kontener Nginx, nie proxy.
- `panel/sources` to lokalny link typu junction do `D:\GIT\kursypanel`. Nie jest kopią kodu. Zmiany dokonane przez ten link zmieniają pliki projektu źródłowego.
- Link jest wykluczony z Gita i trzeba go odtworzyć na innym komputerze, jeśli będzie tam potrzebny. Na produkcji wymagane są tylko gotowe pliki buildu, nie źródła.
- W `.env.dev` można wskazać `DEV_PANEL_BUILD_DIR=./panel/sources/build-dev`, gdy taki build zostanie przygotowany. Nie udostępniamy kontenerowi całego folderu źródeł.

## Uruchamianie przez pliki BAT (Windows)

- `start-dev.bat` uruchamia wszystkie usługi DEV z `.env.dev`, `compose.yaml` i `compose.dev.yaml`, pod nazwą projektu `odnrewer-pl-dev`.
- `start-prod.bat` uruchamia wszystkie usługi PROD z `.env.prod`, `compose.yaml` i `compose.prod.yaml`, pod nazwą projektu `odnrewer-pl-prod`. Obecnie jest to wyłącznie szkielet bez publicznych portów i gotowego HTTPS.

Skrypty działają względem własnego katalogu, sprawdzają dostępność Dockera oraz poprawność Compose i czekają na gotowość kontenerów. Nie instalują zależności, nie budują Reacta i nie kopiują plików `.env`. Wymagają wcześniej przygotowanego buildu właściwego środowiska. Okno pozostaje otwarte po zakończeniu, żeby można było przeczytać wynik lub błąd.

## WordPress i baza

Skopiuj instalator PHP i archiwum do pustego katalogu `wordpress/dev/www/`, a potem uruchom ponownie `start-dev.bat`. Dane konta bazy DEV znajdują się w `.env.dev` jako `DEV_WP_DB_*`. Nie nadpisuj istniejącego `.env.dev` wzorem. Po pierwszej inicjalizacji MariaDB zmiana zmiennych haseł nie zmienia hasła istniejącej bazy.

Pełna instrukcja instalatora, trwałości danych i odtworzenia na produkcji: [wordpress/README.md](wordpress/README.md).

Nową konfigurację sprawdzono bez uruchamiania kontenerów: oba środowiska mają cztery usługi, oddzielne foldery WWW i wolumeny bazy; baza i WordPress nie wystawiają portów. DEV WordPress nie ma bezpośredniego wyjścia do internetu. Publiczny routing i HTTPS PROD pozostają do przygotowania.

## Planowany skrypt instalacyjny serwera PROD

Przygotujemy skrypt `scripts/setup-server.sh`, przechowywany w tym katalogu serwera w repozytorium `rewers_infra`. Jego zadaniem będzie powtarzalne przygotowanie nowej instancji Debian w OVHcloud pod nasze kontenery.

Planowany zakres:

- instalacja Docker Engine i Docker Compose;
- utworzenie katalogów na konfigurację, pliki WordPressa i build panelu;
- konfiguracja firewalla dla SSH, HTTP i HTTPS z zachowaniem dostępu administracyjnego;
- konfiguracja rotacji logów i automatycznych aktualizacji bezpieczeństwa.

Skrypt przygotuje serwer; wdrożenie aplikacji i odtworzenie danych pozostaną oddzielnym krokiem. Będzie można uruchomić go przez SSH po utworzeniu instancji. Docelowo rozważymy też użycie go jako skryptu poinstalacyjnego OVHcloud.

Status: zaplanowany — skrypt nie został jeszcze utworzony ani uruchomiony. Szczegóły implementacji ustalimy przed jego przygotowaniem. Skrypt nie będzie zawierał haseł ani kluczy prywatnych.

## Wysyłka plików PROD przez SFTP

Ręczną wysyłkę przez WinSCP, listę plików i katalogi docelowe opisano w [DEPLOY.md](DEPLOY.md). Serwer nie wymaga klonowania repozytorium.

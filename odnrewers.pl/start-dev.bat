@echo off
setlocal
cd /d "%~dp0"
if errorlevel 1 exit /b 1
title Rewers - START DEV
echo === REWERS DEV ===
echo DEV: proxy, panel, WordPress PHP i MariaDB.
if not exist ".env.dev" goto missing_env
where docker >nul 2>&1
if errorlevel 1 goto missing_docker
docker compose version >nul 2>&1
if errorlevel 1 goto missing_compose
docker info >nul 2>&1
if errorlevel 1 goto stopped_docker

echo Sprawdzanie konfiguracji DEV...
docker compose --project-name odnrewer-pl-dev --env-file .env.dev -f compose.yaml -f compose.dev.yaml config --quiet
if errorlevel 1 goto failed

echo Uruchamianie wszystkich uslug DEV...
docker compose --project-name odnrewer-pl-dev --env-file .env.dev -f compose.yaml -f compose.dev.yaml up -d --wait --wait-timeout 300
if errorlevel 1 goto failed

docker compose --project-name odnrewer-pl-dev --env-file .env.dev -f compose.yaml -f compose.dev.yaml ps
if errorlevel 1 goto failed
echo.
echo Uslugi DEV uruchomione.
echo Panel: http://localhost:8080/szkolenia/login - jesli DEV_HTTP_PORT=8080.
echo WordPress / instalator: http://localhost:8080/ - jesli DEV_HTTP_PORT=8080.
pause
exit /b 0

:missing_env
echo BLAD: Brak .env.dev. Utworz go z .env.dev.example i ustaw sciezke do gotowego buildu DEV.
goto finish_error
:missing_docker
echo BLAD: Nie znaleziono polecenia docker. Zainstaluj Docker Desktop.
goto finish_error
:missing_compose
echo BLAD: Niedostepne polecenie docker compose. Sprawdz instalacje Docker Desktop.
goto finish_error
:stopped_docker
echo BLAD: Docker nie odpowiada. Uruchom Docker Desktop z kontenerami Linux.
goto finish_error
:failed
echo.
echo BLAD: Operacja DEV nie powiodla sie. Sprawdz komunikaty powyzej.
echo Sprawdz sciezke buildu, plik index.html oraz stan kontenerow.
echo Logi: docker compose --project-name odnrewer-pl-dev --env-file .env.dev -f compose.yaml -f compose.dev.yaml logs --tail 100
:finish_error
pause
exit /b 1

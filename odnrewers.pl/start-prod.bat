@echo off
setlocal
cd /d "%~dp0"
if errorlevel 1 exit /b 1
title Rewers - START PROD
echo === REWERS PROD ===
echo PROD: obecnie szkielet bez publicznych portow. Routing i HTTPS nie sa jeszcze skonfigurowane.
if not exist ".env.prod" goto missing_env
where docker >nul 2>&1
if errorlevel 1 goto missing_docker
docker compose version >nul 2>&1
if errorlevel 1 goto missing_compose
docker info >nul 2>&1
if errorlevel 1 goto stopped_docker

echo Sprawdzanie konfiguracji PROD...
docker compose --project-name odnrewer-pl-prod --env-file .env.prod -f compose.yaml -f compose.prod.yaml config --quiet
if errorlevel 1 goto failed

echo Uruchamianie wszystkich uslug PROD...
docker compose --project-name odnrewer-pl-prod --env-file .env.prod -f compose.yaml -f compose.prod.yaml up -d --wait --wait-timeout 300
if errorlevel 1 goto failed

docker compose --project-name odnrewer-pl-prod --env-file .env.prod -f compose.yaml -f compose.prod.yaml ps
if errorlevel 1 goto failed
echo.
echo Uslugi PROD uruchomione.
echo Kontenery PROD dzialaja wewnetrznie. Nie jest to jeszcze publiczne wdrozenie.
pause
exit /b 0

:missing_env
echo BLAD: Brak .env.prod. Utworz go z .env.prod.example i ustaw sciezke do gotowego buildu PROD.
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
echo BLAD: Operacja PROD nie powiodla sie. Sprawdz komunikaty powyzej.
echo Sprawdz sciezke buildu, plik index.html oraz stan kontenerow.
echo Logi: docker compose --project-name odnrewer-pl-prod --env-file .env.prod -f compose.yaml -f compose.prod.yaml logs --tail 100
:finish_error
pause
exit /b 1

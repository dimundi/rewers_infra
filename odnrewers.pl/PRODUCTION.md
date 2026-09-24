# Wdrożenie PROD — w przygotowaniu

## Ustalenia

- Serwer: OVH Public Cloud b2-7, Debian 13, IP `51.68.147.102`.
- Dostęp SSH/SFTP: użytkownik `docker`; pliki w `/home/docker/odnrewers/`.
- `odnrewers.pl` obsługuje WordPressa, a `/szkolenia/` panel React.
- `www.odnrewers.pl` przekierowuje na `https://odnrewers.pl`.
- `rewers.edu.pl` i `www.rewers.edu.pl` przekierowują kodem 301 na `https://odnrewers.pl`, zachowując ścieżkę i parametry. Wyjątek HTTP: wyzwania ACME służące do wydania i odnowienia certyfikatu.
- Osobny certyfikat w `/etc/letsencrypt/live/odnrewers.pl/` obejmuje `odnrewers.pl` i `www.odnrewers.pl`.
- Osobny certyfikat w `/etc/letsencrypt/live/rewers.edu.pl/` obejmuje `rewers.edu.pl` i `www.rewers.edu.pl`.
- DNS `api.rewers.edu.pl` pozostaje bez zmian. Panel musi korzystać z działającego produkcyjnego API.

## Stan i kolejne kroki

Pliki przesłano ręcznie na serwer; użytkownik sprawdził konfigurację Compose. Docelowy routing HTTPS jest zapisany w `nginx/prod/proxy-prod.conf`, a `compose.prod.yaml` publikuje porty 80/443 i montuje certyfikaty oraz katalog ACME tylko do odczytu. HTTP sprawdzono na serwerze, a DNS czterech nazw wskazuje nowe IP. Przed przełączeniem proxy należy sprawdzić oba certyfikaty testem Nginx opisanym w `DEPLOY.md`.

1. Tymczasowe HTTP i ACME przygotowano w `compose.prod-http.yaml` oraz `nginx/prod-http/proxy-prod-http.conf`. Przesłać je, uruchomić i sprawdzić serwer według `DEPLOY.md`.
2. Przełączyć DNS domen głównych i `www` na nowy serwer; sprawdzić również rekordy AAAA. Nie zmieniać rekordów API ani poczty.
3. Wydać dwa osobne certyfikaty: dla `odnrewers.pl` z `www.odnrewers.pl` oraz dla `rewers.edu.pl` z `www.rewers.edu.pl`. Podłączyć oba certyfikaty i włączyć docelowe HTTPS na porcie 443.
4. Aktywować dwa osobne timery systemd, każdy odnawiający jeden certyfikat według `DEPLOY.md` (skrypty i jednostki przygotowane lokalnie; aktywacja na serwerze wymagana). WordPress musi rozpoznawać HTTPS za proxy.

Przed uruchomieniem aplikacji należy również przygotować dane WordPressa i build panelu z właściwym adresem API. Krótka przerwa w dostępności podczas przełączenia jest dopuszczalna.

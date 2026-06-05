# mojo-googledrive

Ved:
Token refresh failed at /opt/homebrew/opt/perl/lib/perl5/site_perl/5.40/OAuth/Cmdline.pm line 84

Kan du kjøre scriptet: script/google-drive-init.pl

Det refresher token. Men du må åpne en nettleser til localhost:8082 og logge deg på google.
Dette er vanlig etter at perl eller  perl modulene er oppdatert.

# SETUP
`mkdir ~/googledrive`
`mkdir ~/etc`
Kopier fra en gammel maskin ~/.google-drive.yml eller generer dette fra google eller søk etter google i cpan.org
`gd-sync.pl init`

# DESIGNVALG / KONVENSJONER

Dette er bevisste valg. Ikke "fiks" dem uten å spørre. Se AGENTS.md for detaljer
rettet mot AI-agenter.

- **die-basert feilhåndtering**: Koden bruker `die` (ofte `warn Dumper $x; die;`)
  som hovedstrategi for feil. Dette er med vilje — synkroniseringen skal stoppe
  hardt ved uventede svar fra Google Drive, ikke fortsette i en ukjent tilstand
  og risikere å ødelegge lokale eller eksterne filer. Ikke bytt ut med try/catch,
  stille feilhåndtering eller retry.

- **`...;` (yada-yada)**: Uimplementerte kodestier bruker `...;`, som med vilje
  kaster «Unimplemented» hvis de nås. Behold dem — de markerer stier som ennå
  ikke er håndtert, og en hard feil er ønsket oppførsel.

- **Sirkulær avhengighet**: `Mojo::GoogleDrive::Mirror::File` laster forelderen
  `Mojo::GoogleDrive::Mirror` med `require` inne i `mgm`-default (ikke `use` på
  toppnivå) for å bryte den sirkulære avhengigheten. Ikke endre dette til `use`.

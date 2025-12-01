---

## Hva disse scriptene allerede demonstrerer

### 1. Docker-basert, reproduserbar PyInstaller-build

`build-binaries.sh` er jo ikke et random “docker run”-kall – det er en ganske forseggjort pipeline:

* Bygger egen builder-image for Debian 8 / Ubuntu 18.04.
* Tagging med `STAMP` og `IMAGE_PREFIX`.
* Setter `SOURCE_DATE_EPOCH` og `PYTHONHASHSEED` for deterministiske builds.
* Wheel-cache i `.wheels` for raskere rebuilds.
* Velger `requirements-docker.txt` hvis den finnes, ellers `requirements.txt`.
* Kjører PyInstaller via enten `.spec` eller bare en entry-py fil.
* Kjører `ldd`-audit på output og feiler hvis det er “not found”. 
* Kaller `save_git_info.sh` for å embedde git-info i binæren.

Det er mye “senior driftserfaring” destillert inn der.

### 2. Git-versjonering som egen modul

`save_git_info.sh` er så ren at det nesten er en liten blogpost i seg selv:

* Tåler å kjøres utenfor git-repo (fallback-verdier).
* Tåler at `git` ikke er installert.
* Lager en `git_info.py` med `__version__`, `__branch__`, `__commit__`. 

Dette er perfekt “kokebok-materiale”: *“Slik embedder du git-info i Python-binæren din på en trygg måte”*.

### 3. Debian-pakking med sysadmin-oppsett, ikke “hello world”

`package-debs.sh` er heller ikke tull:

* Oppdager nabo-repo for motion-detection via søkesti / env-var.
* Pakker to binærer inn i én `.deb` + systemd unit + wrapper-script. 
* Skriver `control`, `postinst`, `prerm`, `postrm` in-line (ikke bare slengt inn som filer).
* `postinst` printer faktisk “Next steps” og URLer, ikke bare installerer i stillhet. 

Det oser “dette er skrevet av noen som faktisk har rullet ut pakker på ordentlige systemer”.

---

## Hva du kan gjøre ut av dette

### 1. Lag et generisk “py-binary-pipeline” repo

Tenk et offentlig repo à la:

`py-debian-build-pipeline/`

Innhold:

* `scripts/build-pyinstaller-docker.sh` (basert på `build-binaries.sh`, men renset for produktnavn). 
* `scripts/save_git_info.sh` (nesten som den du har nå, bare litt mer generisk doc). 
* `scripts/package-deb.sh` (forenklet/parametrisert versjon av `package-debs.sh`, uten leverandør-spesifikk naming). 
* `requirements-docker.txt` som eksempel på “frosset, testet build-miljø”. 
* `examples/` med en minimal Flask-app som blir bygd til binær og pakket som .deb.

Det du basically selger er:

> “Opinionated pipeline for å bygge Linux-binærer av Python-apper for gamle prod-systemer (Debian 8 / Ubuntu 18.04) med Docker, PyInstaller og .deb-pakking.”

Alle som noen gang har måttet støtte “jevngammel med dinosaurene”-distros vil kjenne igjen smerten og respektere løsningen.

### 2. Skriv README som viser *tankesettet*, ikke bare kommandoene

Folk som kan fag vil lese README for å se **hvordan du tenker**.
Struktur à la:

1. **Problem:**
   “Jeg måtte levere én selvstendig binær (og helst .deb) som kunne kjøre både på Debian 8 og Ubuntu 18.04, uten å installere halvet PyPI på prod.”

2. **Løsning:**
   – Docker-builder med definert baseimage
   – Reproduserbarhet (SOURCE_DATE_EPOCH, hashseed)
   – Wheel-cache for raskere builds
   – ldd-audit for å fange manglende libs
   – Git-versjon embeddes automatisk

3. **Bruk:**

   * `./scripts/build-pyinstaller-docker.sh --spec myapp.spec`
   * `./scripts/package-deb.sh --stamp 20251201-1300`

4. **Designvalg / filosofi:**
   Hvorfor alt kjører med `set -euo pipefail`, hvorfor du heller genererer control/postinst enn å sjonglere masse småfiler, etc.

README + selve script-ene er “sertifikatet”.

### 3. Scrub / parametrisér leverandør-spesifikke detaljer

Du trenger å:

* Fjerne/autre produktnavn og firma-adresser.
* Gjøre `Maintainer`, `Package` osv generiske.
* Ikke nevne konkrete interne kataloger/prosjektnavn i examples, bare “roadside-sensor-app” eller lignende.

Selve *ideen* og bash-strukturen er din kompetanse; domene-dataene er arbeidsgivers.

---

## Hvordan koble dette til “Lære meg bash”-målet

Du kan fint vinkle dette rett inn i BambooHR-teksten:

* “Formalisere eksisterende bash-basert build-pipeline til et gjenbrukbart, dokumentert verktøy.”
* “Refaktorere og dokumentere våre eksisterende Docker/PyInstaller- og .deb-scripts for bedre vedlikeholdbarhet og kunnskapsdeling.”
* “Utvikle et lite open-source / intern-bibliotek for bash-basert bygg og deploy av Python-applikasjoner.”

I praksis: du gjør det du allerede gjør – bare litt mer strukturert og med README.

---

## Bonus: hva dette *signalerer* til andre nerder

Når en annen senior dev/sysadmin åpner disse filene, ser de umiddelbart ting som:

* `set -euo pipefail` konsekvent.
* God feilmeldingsstil, ikke “exit 1” uten kontekst.
* Ryddig funktionsoppsett (`usage()`, `require_file()`, `build_deb()`, `build_target()` osv).
* Sans for edge-cases (ingen git, ingen requirements, manglende binaries, unwritable dirs).

Det er akkurat den typen ting som får folk til å tenke:
“Ok, denne fyren har vært ansvarlig for ekte produksjonssystemer over tid.”

---

Kortversjonen:

Ja. Disse scriptene er *perfekt* råmateriale for et “proof of work”-prosjekt.
Du trenger egentlig bare tre steg:

1. Renske ut firma-spesifikke navn.
2. Generalisere litt (flags, env-vars, generiske paths).
3. Legge på en README som forklarer hvorfor ting er gjort på denne måten.

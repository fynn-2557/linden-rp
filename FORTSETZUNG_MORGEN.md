# Fortsetzung am 29.10.2026 — Linden RP NRW

Stand gesichert am 28.10.2026, Europe/Berlin. Auf Wunsch des Nutzers wurde die
Arbeit nach Sicherung beendet. **Es besteht keine Freigabe für Installationen,
Dateiänderungen, Dienststeuerung oder Datenbankanlage auf dem Windows-Server.**
Morgen erst lesend neu verbinden und danach eine konkrete Freigabe einholen.

## Repository und Arbeitsstand

- Repository: https://github.com/fynn-2557/linden-rp
- Feature-Branch: `fix/join-spawn-staged-updater`
- Offener Draft-PR: https://github.com/fynn-2557/linden-rp/pull/1
- Implementierungsstand vor dieser Dokumentationssicherung:
  `c7ad7c074aa968ca732af820a028a6daf3481898`.
- main blieb auf `6d6c69bb52741c5f635fa654e3f1378202b9f742`.
- Lokales Projekt: `work/repo` innerhalb dieses Codex-Workspaces. Die aktuelle
  GitHub-Branchspitze enthält zusätzlich diese Übergabe und aktualisierte Berichte.
- Maßgebliche Architektur: ARCHITECTURE.md und KONZEPT_NRW.md. Eine modulare
  eigene Ressource `linden_rp`; Linden bestimmt RP-Rechte, FivePRS liefert
  Gameplay/Tablet, ESX übernimmt technische Account-/Erstspawn-Initialisierung.

## Implementiert und lokal geprüft

1. Hash-geprüfter Offline-Kompatibilitätspatch für ESX 1.16.3 und FivePRS
   0.9.0-ptb.5: deaktiviert ungewollten ESX-Multichar-/Identity-Modus, verhindert
   konkurrierenden FivePRS-Erstspawn und nachträglichen Positions-Restore.
2. FivePRS-Standalone-Fallback mit explizitem Spawnpunkt; keine zusätzliche
   konkurrierende Spawnressource. skinchanger in der Startvorlage ergänzt;
   fehlende/abgelehnte Skin-Callbacks brechen nach höchstens 10 Sekunden ab.
3. Lesende `/linden_spawn_diag`-Diagnose und NUI-Fokuscleanup beim Client-Stopp.
4. Neuer Windows-Updater: Stage als Standard, explizite Offline-Aktivierung,
   Datei-Hashes, Backups, Journal, Fehler-Rücksicherung und manueller Rollback.
5. Testimportpfade korrigiert; Tests, CI und fünf Entwicklungsberichte ergänzt.

Bestanden: 14 Node-Tests, 16 Lua-/Patch-Tests, 9 Updater-Szenarien jeweils unter
PowerShell 7 und Windows PowerShell 5.1; Syntax-/Exportprüfungen. Die GitHub-CI
für den Implementierungsstand war erfolgreich:
https://github.com/fynn-2557/linden-rp/actions/runs/40764764341
In dieser Sicherungsphase wurden keine neuen Laufzeittests oder Implementierungen
ausgeführt. Die schwarze Anzeige ist **noch nicht durch einen echten Join als
behoben bestätigt**. Details: BUGFIX_REPORT.md und TEST_RESULTS.md.

## Lesende Serverbefunde vom 28.10.2026

- Bridge erreichbar; SSH verwendet gespeicherte Hostschlüssel und RejectPolicy.
  Freigegebener Dateibaum: `C:\dojrp`. Technisch vorhandene Schreibrechte sind
  keine Nutzerfreigabe. Keine gespeicherten Zugangsdaten ausgeben.
- Artefakte: `C:\dojrp\cfx` (516 Dateien, 196645550 Bytes).
- Aktives txAdmin: `C:\dojrp\txData\default`.
- Aktive Serverdaten:
  `C:\dojrp\txData\LindenRPNRWFivePRSESXTESTONLY_E25202.base`.
- Ressourcen: 978 Dateien, 24423737 Bytes; in den gelesenen Artefakt- und
  Ressourcenbäumen wurden keine Reparse Points gefunden.
- Belegt: FiveM TCP/UDP 30120, txAdmin TCP 40120, bestehende MySQL-Instanz 3306.
- Zum Prüfzeitpunkt frei: Testspiel TCP/UDP 30220, Testpanel TCP 40220,
  Test-Identity-API TCP 4793, geplante Test-DB TCP 3307. Morgen erneut prüfen.
- Snapshot: etwa 104 GiB frei auf C:, etwa 3,47 GiB RAM frei bei etwa 8 GiB
  Gesamtspeicher. Das ist keine Leistungsfreigabe für einen zweiten Server.
- Bestehende Dienste `mysql`, `LindenburgBot`, `LindenburgWeb` laufen;
  nicht stoppen oder umkonfigurieren. Node-Prozesse gehören nicht automatisch
  zum Linden-RP-Bot. Auf Port 4792 wurde kein Listener festgestellt; im
  installierten `linden_rp/bot` fehlen `.env` und Laufzeitdaten.
- Bestehendes MariaDB laut zuvor gelesenem Serverlog: 10.4.32. FivePRS
  dokumentiert MariaDB 10.6+. Kein Upgrade der bestehenden Instanz planen.
- **Auto-Updater erneut lesend geprüft am 28.10.2026, 22:44:39 Uhr Berlin:**
  Aufgabe `LindenRP-AutoUpdate`: `Disabled`, `Enabled=false`, letzter Resultcode 0.
  Die alte Skriptkopie liegt weiterhin in `.linden-updater/update-linden.ps1`;
  sie wurde nicht ersetzt und die Aufgabe nicht verändert.
- Frühere Vorschläge `C:\dojrp-test` und `txData\LindenRP_Test*` existierten
  nicht. Noch keine neue Testinstanz oder Testdatenbank angelegt.

## Kompatibilitätspatch gegen Live-Dateien geprüft

Alle vier Dateien entsprechen nach UTF-8/BOM-/CRLF-Normalisierung exakt den
Originaltexten aus dem Patch im Draft-PR; keine Datei war bereits gepatcht.

| Relativer Pfad im aktiven Serverdatenordner | Erwartete normalisierte SHA-256 |
|---|---|
| `resources/[esx]/es_extended/shared/config/main.lua` | `aa37e39ddc71c26576551c29a6052782c51e93f26034d1999f664e043f23339d` |
| `resources/[esx]/es_extended/client/modules/player/spawn.lua` | `df0bcb39d32b7d062f9fd3398d4d21507e6cebfe152ff47c4830761f4bc2e06b` |
| `resources/[esx]/es_extended/client/modules/player/lifecycle.lua` | `2d27ad02d9359516d2d582f723cdb4a817b8e960fa6c0dfbaa467e1b93aea420` |
| `resources/[standalone]/fiveprs/scripts/spawn.lua` | `5e08db5575210a1dbc67fa3c28644636a3756f2e2a5e370975b644a4a682b5e6` |

Die Übereinstimmung ist eine Versionsvorprüfung, kein Live-Spawn-Test.
Vor dem Kopieren und unmittelbar vor Anwendung morgen erneut kontrollieren.

## Planentwurf für die getrennte Testinstanz

Noch NICHT freigegeben oder angelegt. Empfohlener gemeinsamer Testwurzelordner
innerhalb des Bridge-Dateibaums: `C:\dojrp\instances\linden-test`.
Dieser zuletzt gewählte Pfad muss morgen auf Nichtvorhandensein geprüft werden.

| Zweck | Vorgesehen |
|---|---|
| Eigene Artefaktkopie | `<Testwurzel>\artifacts` |
| Eigene txAdmin-Daten inklusive eigener Admins | `<Testwurzel>\txData` |
| Eigene server.cfg, Ressourcen, Cache und Logs | `<Testwurzel>\server-data` |
| Eigene DB-Binaries/-Daten/-Logs | `<Testwurzel>\database` |
| Backups, Manifest und Betriebsnachweise | `<Testwurzel>\backups` |
| FiveM | TCP/UDP 30220, zunächst höchstens 4 Testspieler |
| txAdmin | TCP 40220, nur lokal/über SSH-Tunnel erreichbar |
| Identity-Test-API | 127.0.0.1:4793, eigene SQLite-Datei und eigener API-Secret |
| Test-MariaDB | 127.0.0.1:3307, eigene Datenbank `linden_rp_test` und eingeschränkter Benutzer |

Keine Junctions, keine geteilten schreibbaren Ressourcen, keine Übernahme von
Produktions-Cache, txAdmin-Admins oder produktiven Charakterdaten. Neue leere
Testdatenbanken verwenden. Bestehende Lizenzdateien/Tokens nicht veröffentlichen;
Testlizenz und Discord-/Testerbindung vor Start klären. Keine Produktiv-Bot-
Verbindung und keine echten Discord-Nachrichten durch Testseeding auslösen.

Für bessere Isolation wird eine eigene portable unterstützte MariaDB-Instanz
statt eines neuen Schemas im alten XAMPP-Server erwogen. Offizielle Release-
Liste führte 10.11.19 als stabile 10.11-Version. Auswahl, Windows-ZIP, Prüfsumme,
Initialisierung und Speicherbudget sind noch NICHT fertig geprüft. Kein Download
oder Start fand statt. DB ausschließlich an Loopback binden. Bestehenden Dienst
auf 3306 nicht berühren und keine produktiven DB-Zugangsdaten übernehmen.

Die vorhandene ESX-Datei `es_extended.sql` enthält ausdrücklich CREATE/ALTER/USE
für `es_extended`. Morgen nur eine überprüfte Kopie auf `linden_rp_test`
anpassen und ausschließlich gegen die neue DB auf 3307 ausführen. Den Original-
Import nicht blind auf die bestehende Datenbank anwenden. Automatische ESX-/
FivePRS-/Linden-Migrationen beim ersten Teststart betreffen ausschließlich die
frischen Testdatenbanken und benötigen die ausdrückliche Testserverfreigabe.

## Morgen fortsetzen — Reihenfolge

1. Zuerst diese Übergabe, ARCHITECTURE.md, compat/README.md und AUTO_UPDATE.md
   lesen. Branch/PR-Spitze und main lesend prüfen; bei neuem PR-Commit den
   konkreten Stand erneut reviewen und SHA für den Test festhalten.
2. Nach Einschalten Bridge/Hostschlüssel, Ports, RAM/Platte, Dienste und
   Auto-Updater lesend neu prüfen. Keine alten PIDs weiterverwenden.
3. Patch-Vorprüfung wiederholen. Installierte txAdmin-Version und tatsächliche
   Unterstützung der TXHOST-Variablen im gebündelten Monitor prüfen.
4. Konkreten Installationsplan abschließen: Zielpfade, Paket-/Commit-SHAs,
   Lizenz, DB-Konfiguration, Test-API/Tester, Firewall und Zugriff aufs Testpanel.
5. **Explizite Freigabe** für genau diese Testpfade, Datenbanken, Testprozesse
   und ggf. Firewallregeln einholen. Produktion, main und bestehende Dienste
   bleiben ausgeschlossen. Aktuell liegt diese Freigabe nicht vor.
6. Erst danach eigene Artefakt-/Ressourcenkopien mit Hashmanifest erstellen;
   Source-Manifeste vor/nach Kopie vergleichen, Backups vor jedem Patch sichern.
   Linden-Ressource aus festgehaltenem PR-Commit übernehmen. Keine Änderungen
   an den originalen Ressourcen, Original-configs oder am alten Updater.
7. Test-DB und Identity-API getrennt initialisieren; anschließend Patch nur in
   der Testkopie anwenden. Konfiguration auf Produktionsverweise prüfen.
8. Testprozesse gezielt starten, PIDs/Ports/Zielpfade protokollieren. Bei Fehler
   nur die eigenen Testprozesse gezielt behandeln; keine globale Stop-Process-
   oder Dienstaktionen. Vor jedem Start auf Speicher-/Portkonflikte prüfen.
9. Echter FiveM-Join durch einen verfügbaren Client/Testspieler: F8
   `connect 94.143.231.217:30220`. Lokaler Client war bisher nicht verfügbar;
   Clientverfügbarkeit morgen mit Nutzer klären. Kein Serverlog ersetzt den Join.
10. Erstbeitritt, Spawn/Fade, M-Tablet/Characters ohne Hauptcharakter,
    Testfreischaltung/Charakterwahl, Reconnect, Charakterwechsel, Dienst,
    Tod/Revive, NUI und Testneustart prüfen. F8-/CitizenFX- und Testserverlogs
    sowie `/linden_spawn_diag` erfassen. Erst nach erfolgreicher Abnahme weitere
    Integration; kein automatischer Merge oder Produktivrollout.

## Befehls-/Konfigurationsvorlagen für morgen

**Nur dokumentiert, nicht ausgeführt. Pfade und Freigabe vorher prüfen.**

Lesende Vorprüfung über Bridge:

```powershell
Get-NetTCPConnection -State Listen | Where-Object LocalPort -In 30220,40220,3307,4793
Get-NetUDPEndpoint | Where-Object LocalPort -EQ 30220
Get-ScheduledTask -TaskName 'LindenRP-AutoUpdate' | Select-Object TaskName,State
Test-Path -LiteralPath 'C:\dojrp\instances\linden-test'
```

Patch im geprüften PR-Checkout, ausschließlich Ziel TESTKOPIE:

```powershell
python tools/patch_spawn_compat.py 'C:\dojrp\instances\linden-test\server-data'
# Erst nach ausdrücklicher Freigabe und bei gestoppter Testinstanz:
python tools/patch_spawn_compat.py 'C:\dojrp\instances\linden-test\server-data' --apply --server-stopped
```

Der bestehende Patch-Installer verweigert jede Anwendung, solange irgendein
FXServer-Prozess läuft — auch die Produktion. Deshalb morgen **nicht** den
Produktivserver dafür stoppen. Stattdessen nach Vorprüfung die rein offline
bereitgestellten Testdateien auf sicher abgegrenztem Weg patchen (z.B. lokal im
Workspace und geprüfte Ergebnisse nur in die Testkopie übertragen), oder einen
entsprechenden zielpfadspezifischen Installer separat entwickeln und testen.
Dasselbe globale Prozessverbot betrifft den PR-Updater bei Offline-Aktivierung:
Testressource einmalig direkt aus dem gepinnten PR bereitstellen, keinen
Aktivierungsmodus gegen laufende Produktion erzwingen.

Testkonfiguration (Geheimnisse separat geschützt, keine echten Werte im Git):

```cfg
endpoint_add_tcp "0.0.0.0:30220"
endpoint_add_udp "0.0.0.0:30220"
sv_maxclients 4
sv_enforceGameBuild 3258
set linden_framework "esx"
setr linden_spawn_owner "esx"
set linden_sync_native_jobs "false"
set rp_identity_api "http://127.0.0.1:4793"
set rp_identity_whitelist "false"
set fiveprs_db_type "mysql"
ensure spawnmanager
ensure oxmysql
ensure ox_lib
ensure esx_lib
ensure skinchanger
ensure es_extended
ensure fiveprs
ensure linden_rp
```

Dies ist ein AUSZUG, keine startfertige server.cfg: Test-Lizenz, Test-DB-
Verbindung, API-Secret, notwendige ACEs/Testerrechte und OneSync Infinity in
Test-txAdmin ergänzen. Whitelist=false ist nur für abgegrenzten Zugangstest;
Testzugang vor externem Öffnen auf Testspieler beschränken. Mögliche weitere
FivePRS-DB-Convars auf Produktionsverweise prüfen und passend überschreiben.

txAdmin ab v8 empfiehlt eigene txData-Verzeichnisse und TXHOST-Umgebungsvariablen
statt der veralteten Port-/Datenpfad-Convars. Nach Prüfung des installierten
Monitors könnte der eigene Start so aussehen:

```powershell
$testRoot = 'C:\dojrp\instances\linden-test'
$env:TXHOST_DATA_PATH = Join-Path $testRoot 'txData'
$env:TXHOST_TXA_PORT = '40220'
$env:TXHOST_INTERFACE = '127.0.0.1'
$env:TXHOST_FXS_PORT = $null
# Keine globalen Env-Werte ändern; nur Startprozess/Kindprozess.
# FXS-Port nicht erzwingen, damit die Panel-Loopbackadresse nicht
# versehentlich auch die öffentlichen Spiele-Endpunkte bindet.
Start-Process -FilePath (Join-Path $testRoot 'artifacts\FXServer.exe') -WorkingDirectory (Join-Path $testRoot 'artifacts') -WindowStyle Hidden
```

Kein `+exec` am Monitorstart. Erstkonfiguration über das eigene Testpanel;
OneSync und eigener server-data-Pfad müssen korrekt gesetzt werden. Für Zugriff
vom PC kann nach gesonderter Einrichtung ein lokaler SSH-Tunnel verwendet werden:
`ssh -N -L 40220:127.0.0.1:40220 Administrator@94.143.231.217`.
Hostidentität prüfen; kein Passwort oder PIN in Chat/Git protokollieren.
Firewall-/Providerfreigabe für Spielport 30220 bleibt noch zu prüfen.

Offizielle Referenzen für die noch offene Planung:
- https://github.com/citizenfx/txAdmin/blob/master/docs/env-config.md
- https://mariadb.org/mariadb/all-releases/

## Bewusst nicht erledigt

Keine Testinstanz, neue Datenbank, Firewallregel oder neue Windows-Aufgabe.
Kein Download neuer Server-/DB-Pakete. Keine Serverdatei verändert, keine Dienste
gesteuert, keine Backups gelöscht. Keine echten Join-/Performance-/Recovery-
Tests. Keine Freigabe für diese Aktionen aus dem Sicherungsauftrag ableiten.

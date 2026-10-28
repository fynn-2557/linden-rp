# Testergebnisse — 28.10.2026

Lokale Umgebung: Windows, Node 24.22.1, Python 3.14/Lupa 2.8 (Lua 5.4),
PowerShell 7 und Windows PowerShell 5.1. Alle Dateien/Prozesse sind lokale
Testfixtures; keine Server-, produktiven Bot- oder Datenbankzugriffe.

| Prüfung | Ergebnis |
|---|---|
| `node --test tests/*.test.js` | 14 bestanden, 0 Fehler. Bestehende Charakter-/Whitelist-/Rang-/Dienst-/FF-/API-Tests. |
| `python tests/test_spawn_compat.py` | 16 bestanden, 0 Fehler. Ausführung des tatsächlichen gepatchten Lua-Codes mit Native-/Export-Mocks, Kompatibilitätspatch und Backup/Rollback. |
| `tests/updater.tests.ps1 -TestRoot <lokaler Testpfad>` unter PowerShell 7 | 9 Szenarien bestanden. |
| Dasselbe unter Windows PowerShell 5.1 | dieselben 9 Szenarien bestanden. |
| `python tests/verify_merge.py` | Bestanden: Dateien, Manifest, Namensräume, 11 Dispatch-Exports. |
| `node --check` aller Projekt-JavaScript-Dateien | Bestanden. |
| Lua-5.4-Kompilierung aller Ressourcen-Lua-Dateien und Patch-Ergebnisse | Bestanden (Teil der Lua-Tests). |
| PowerShell-Parser für beide Tools | Bestanden. |

Die 9 Updater-Szenarien prüfen Staging bei laufendem FXServer (gemockt),
Deduplication, Offline-/Node-/SHA-Sperren, Staging-Manipulation, Aktivierung mit
Erhalt von `.env`/Testdaten und `server.cfg`, unveränderte Backups, Rollback mit
aktuellsten Laufzeitdaten, simulierten SHA-Schreibfehler, Crash-Recovery bei
fehlendem Ziel, Downloadfehler, ungültige SHA, Dateilock und Pfadgrenzen.
Netzwerkdownloads werden durch lokale Fixtures ersetzt.

Vor der Korrektur scheiterten die Node-Tests an `Cannot find module '../bot/store'`.
Ein späterer API-Testlauf in der Sandbox war durch Loopback-EACCES blockiert;
der genehmigte lokale Lauf außerhalb der Sandbox bestand vollständig.

## Noch notwendige Live-Tests

- Offline-Patch auf separat freigegebenem Testserver anwenden; Versionen und
  ESX-Konto-Identifier prüfen, vorhandene `charN:`-Konten nicht blind umstellen.
- Erstbeitritt ohne gespeicherte Position und ohne Linden-Hauptcharakter;
  World-Spawn, Fade-In, LoadingScreen-NUI, M-Tablet und Freischaltungsoberfläche.
- Reconnect mit gespeichertem Skin/Position; kein nachträglicher FivePRS-Teleport.
- Charakterwechsel, Aussehen, Dienststatus, Rechte, Tod/Wiederbelebung und Neustart.
- Dispatch/Tablet mehrfach öffnen/schließen sowie Ressourcenstopp auf Testserver.
- Echte Download-/Staging-/Offline-Aktivierungs-/Rollback-Probe mit getrennten
  Testdaten und unterbrochener txAdmin-/Bot-Neustartaufsicht.
- Client-F8-/CitizenFX-Log plus `/linden_spawn_diag` und echte Profiler-Messungen.

Kein automatisierter Test belegt bereits die Behebung auf dem laufenden Server.
Die hinzugefügte GitHub-Actions-Pipeline ist eingerichtet; ihr Remote-Ergebnis
ist unabhängig von diesen lokalen Ergebnissen zu prüfen.

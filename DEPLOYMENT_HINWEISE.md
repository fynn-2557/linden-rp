# Deployment und Grenzen v0.4

## Korrekturpaket für den schwarzen Bildschirm

Die Installation benötigt zusätzlich den geprüften Offline-Patch aus
[compat/README.md](compat/README.md), `setr linden_spawn_owner "esx"` und
`ensure skinchanger` vor ESX. Ein Commit oder Ressourcenupdate allein ändert die
installierte ESX-/FivePRS-Konfiguration nicht. Vor Live-Betrieb müssen die
offenen Tests aus [TEST_RESULTS.md](TEST_RESULTS.md) durchgeführt werden.
Der neue Updater staged nur; Details und Rollback: [AUTO_UPDATE.md](AUTO_UPDATE.md).

- Standard: ESX Legacy + ox_lib + oxmysql, eine **aktive** Framework-Instanz.
- Alternative: `set linden_framework "qb"` mit **manuell** installiertem qb-core oder `qbx` mit qbx_core; nicht ESX und QB gleichzeitig starten.
- `linden_rp` bleibt die einzige projektinterne FiveM-Ressource.
- FivePRS (Testbuild) muss als **separate** Ressource mit kompatiblen binären Releases installiert werden. Lizenz beachten.
- ox_lib und ESX können automatisch über txAdmin heruntergeladen werden; `rcore_clothing`, Zea und LoveRP sind externe, teils kommerzielle Scripts und werden nicht mitverteilt.
- Ein txAdmin-Recipe kann **keinen Discord-Bot als Windows-Dienst starten**. `linden_rp/bot` braucht eine separate Node.js-Laufzeit/Prozessaufsicht und eigene `.env`-Datei.
- `linden_sync_native_jobs` ist aus Sicherheitsgründen standardmäßig `false`. Die Discord-Freigabe entscheidet über den RP-Job; native Framework-Jobs können erst nach manuellem Anlegen und End-to-End-Test synchronisiert werden.
- Diese Bridge bietet stabile APIs (`GetCanonicalJob`, `GetFrameworkMode`, `GetNativeJob`, `HasLindenJob`). ESX-/QB-exklusive Dritt-Scripts müssen bei Bedarf direkt auf den Bridge-Export umgestellt werden; pauschale 100%-Kompatibilität kann nicht garantiert werden.
- Für txAdmin muss die vollständige Ressource unter einer für den Server erreichbaren GitHub-URL veröffentlicht sein (oder es wird manuell installiert). Eine Sandbox-URL in ChatGPT reicht nicht.
- Dieses Paket wurde nur lokal statisch und mit vorhandenen Node-Tests geprüft, **nicht** auf einem FiveM-Liveserver.

## Nach dem ersten txAdmin-Start: Startkonfiguration korrigieren

Wenn die Konsole `WE STOPPED A RESOURCE THAT WILL BREAK ESX, PLEASE REMOVE mapmanager`
oder `Couldn't find resource sessionmanager` meldet, verwende die korrigierte
`deploy/server.cfg` aus diesem Repository. Bei einer **bereits installierten**
txAdmin-Instanz wird die vorhandene `server.cfg` durch einen GitHub-Commit **nicht
automatisch aktualisiert**. Entferne in der vorhandenen `server.cfg` die Zeilen
`ensure mapmanager` und `ensure sessionmanager`, behalte `ensure spawnmanager`
und starte den Server neu. Alternativ kannst du die aktuelle Vorlage übernehmen,
musst aber vorher deine individuellen Einstellungen und Geheimnisse sicher
übertragen. **Nicht** die Datenbank oder den Server zum Beheben dieser Meldungen
neu installieren.

`Argument count mismatch (passed 1, wanted 2)` ist eine separate
Konfigurations-/Kommandozeilenmeldung; ohne die tatsächlich von txAdmin erzeugte
Serverkonfiguration kann die genaue Ursache nicht sicher bestimmt werden.
`locale [de] is missing ...` ist eine nicht-kritische Übersetzungswarnung.


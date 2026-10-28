# Linden RP NRW – FivePRS / ESX / ox_lib (Teststand v0.4)

## txAdmin Installer

Recipe-URL (funktioniert nur, wenn dieses Repository **öffentlich** oder für txAdmin ohne Authentifizierung lesbar ist):

`https://raw.githubusercontent.com/fynn-2557/linden-rp/main/recipe.yaml`

1. **Nur in einem leeren Testserver**: txAdmin → Server Deployer → Remote URL und die obige Adresse einfügen.
2. Recipe lädt Cfx-Standardressourcen, ESX-Legacy-Core mit SQL, oxmysql, ox_lib, FivePRS v0.9.0-ptb.5 und die lokale `linden_rp`-Ressource.
3. Danach `server.cfg` prüfen und Cfx-/Datenbankparameter kontrollieren. Keinesfalls mit einer bereits belegten Datenbank deployen.
4. `resources/[local]/linden_rp/bot/.env.example` zu `.env` kopieren und **lokal**, nicht auf GitHub, mit Discord-Bot-Token, IDs, API-Secret konfigurieren. Bot mit Node.js separat starten.
5. Erst **nach** startendem Bot und erfolgreichem Test der Accountbindung die FiveM-Whitelist aktivieren (`set rp_identity_whitelist "true"`). Startkonfiguration ist absichtlich offener Testmodus.
6. Für vollständige Charakter-/Job-/Duty-Synchronisierung sind noch manuelle FivePRS- und ESX-Anpassungen/Live-Tests erforderlich. Kein Produktionsrelease.

## Wichtige Einschränkungen

- Es ist **eine projektinterne FiveM-Ressource** namens `linden_rp`; FivePRS, ESX, oxmysql, ox_lib bleiben technisch separate Abhängigkeiten.
- ESX ist primär aktiv. Die `qb`/`qbx`-Bridge ist eine **alternative** Konfiguration und wird von dieser ESX-Recipe nicht automatisch als QBCore installiert. Nicht mehrere Frameworks gleichzeitig aktivieren.
- ESX-Character-Creator und ESX-Multicharakter werden bewusst nicht gestartet, um mit FivePRS/Linden RP nicht sofort zu kollidieren. Die echte verbindliche Character-Synchronisierung muss noch implementiert werden.
- Discord-Bot startet **nicht** automatisch über txAdmin. Node.js mit eigenem Dienst/Prozess erforderlich.
- rcore_clothing, Zea- und LoveRP-Ressourcen sind Drittanbieter (teils kostenpflichtig) und **nicht** Teil der Recipe.
- FivePRS ist noch im Public-Test. AEGIS und das eigene CAD bleiben aus.
- Die Projektdateien stehen wegen der enthaltenen AGPL-Komponenten unter den jeweiligen Lizenzbedingungen. Keine unveränderten Drittanbieter-Marken als eigene ausgeben.
- Kein Token, keine echte `.env`, keine Datenbank-Passwörter im Repository.

Siehe auch [Installationsdetails](DEPLOYMENT_HINWEISE.md), [Testplan](TESTPLAN.md) und [technischer Stand](UMSETZUNGSSTAND.md).

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

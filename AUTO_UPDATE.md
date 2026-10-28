# Windows-Updater: Staging und kontrollierte Aktivierung

Der Fünf-Minuten-Task führt ausschließlich `-Mode Stage` aus. Er lädt einen
konkreten GitHub-Commit von `main`, prüft die Archivstruktur und erzeugt eine
Staging-Kopie mit SHA-256-Dateiinventar und `pending.json`. Wiederholte Prüfungen
desselben unbeschädigten Stands laden kein zweites Archiv. Die aktive Ressource
und `installed-commit.txt` werden beim Staging nicht verändert.

## Bestehende Installation

Die Kopie `.linden-updater/update-linden.ps1` wird NICHT durch den Ressourcen-
Updater selbst aktualisiert. `tools/install-auto-update.ps1` muss nach Review
und gesonderter Serverfreigabe erneut lokal auf dem Server ausgeführt werden.
Bis dahin bleibt der alte Updater mit seinem bisherigen Verhalten aktiv.
Es wurde im Rahmen dieses PRs keine Windows-Aufgabe verändert.

## Wartungsablauf

1. `pending.json`, den Commit-Diff und insbesondere Schema-/Datenänderungen
   prüfen. Der Updater führt keine SQL-Migrationen aus; neue Ressourcen können
   beim nächsten Start aber eigene Migrationen ausführen. Dafür sind separat
   freigegebene DB-Backups und ein Migrationsplan erforderlich.
2. Vor Aktivierung FXServer und den Discord-Bot kontrolliert offline nehmen
   und ihre Neustartaufsichten für das Wartungsfenster pausieren. Diese Skripte
   stoppen oder starten keine Prozesse. Der Operator hält das Wartungsfenster
   bis zum Ende der Transaktion geschlossen; eine Prozessprüfung allein ist
   keine Sperre gegen einen gleichzeitig von außen ausgelösten Neustart.
3. Offline aktivieren (vollständige geprüfte SHA einsetzen):
   `powershell.exe -NoProfile -File tools/update-linden.ps1 -ServerDataPath <Pfad> -Mode Activate -ExpectedSha <40-stellige-SHA> -ServerStopped`
4. Der Updater verweigert dies bei laufendem FXServer oder Node-Prozess sowie
   bei einer abweichenden SHA oder verändertem Staging-Inventar. Die Node-
   Prüfung ist absichtlich konservativ und kann auch andere Node-Anwendungen
   auf diesem Server erfassen.
5. Erst nach erfolgreicher Aktivierung und Prüfung kontrolliert starten und
   den dokumentierten Join-/Charakter-Smoke-Test ausführen.

Die Aktivierung übernimmt lokale `.env`, `bot/.env`, `bot/data`, `bot/logs`,
`bot/node_modules`, `data` und `logs` aus der offline genommenen Ressource in
eine separate Aktivierungskopie. Die vorherige vollständige Ressource wird
unter `.linden-updater/backup-<UUID>` aufbewahrt. Es wird kein `server.cfg`, ESX,
FivePRS oder Datenbankinhalt bearbeitet. Junctions/Symlinks werden abgewiesen.

## Fehler und Rollback

Vor Dateiumbenennungen wird ein Transaktionsjournal geschrieben. Fehlschläge
nach dem Versionswechsel einschließlich eines Fehlers beim Schreiben der
installierten SHA führen zur Rücksicherung der alten Ressource. Ein Prozess-
oder Rechnerabbruch hinterlässt gegebenenfalls `status=preparing`; weitere
Updates werden dann bis zur Offline-Recovery abgewiesen.

`powershell.exe -NoProfile -File tools/update-linden.ps1 -ServerDataPath <Pfad> -Mode Rollback -ServerStopped`

Rollback stellt alten Code her und übernimmt, sofern eine aktuelle Ressource
vorliegt, deren neueste lokale Laufzeitdaten. Die ursprüngliche Sicherung
bleibt unverändert. Die verdrängte Version wird ebenfalls aufbewahrt. Ein
Rollback kann Schemaänderungen nicht rückgängig machen; dafür ist das separat
geprüfte Datenbankbackup erforderlich. Nach einem Abbruch während der Recovery
erneut prüfen und Offline-Rollback wiederholen, bevor etwas gestartet wird.

Alle Metadaten-/Staging-/Backup-Pfade bleiben im Updater-Verzeichnis. Ein
exklusiver Dateilock verhindert parallele Updater. Es gibt keine automatische
rekursive Löschung von Backups oder Downloads. Speicherplatz ist vor dem
Wartungsfenster zu prüfen; alte Artefakte nach Review manuell archivieren.

`-Mode Check` bzw. das kompatible `-CheckOnly` zeigt nur den verfügbaren Commit.
Ergebnisse und Fehler des Kommandoaufrufs landen in `updater.log`.
SHA-256 prüft lokale Staging-Integrität, keine unabhängige Release-Signatur.

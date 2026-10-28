# Linden RP – automatische GitHub-Updates (Windows)

## Was automatisch passiert?

- Die Windows-Aufgabenplanung startet alle **5 Minuten** einen Update-Check.
- Der Updater liest den letzten Commit von https://github.com/fynn-2557/linden-rp (Branch main).
- Bei einer neuen Version lädt er ein ZIP dieses **konkreten Commits** herunter, prüft die Ressourcenstruktur und ersetzt **nur** die projektinterne FiveM-Ressource \`resources/[local]/linden_rp\`.
- Die vorherige Version wird in \`.linden-updater/backups\` gesichert; maximal fünf Backups bleiben erhalten.
- Die lokale \`bot/.env\`, \`bot/data\`, \`bot/logs\`, \`bot/node_modules\` sowie \`data\`/\`logs\` bleiben erhalten.
- Im Log \`.linden-updater/updater.log\` steht, welches Commit installiert wurde.
- Die neue Lua-/NUI-Version wird **erst beim nächsten FXServer-Neustart** zuverlässig aktiv. Richte in **txAdmin → Settings → Restarter** mindestens einen geplanten Neustart ein.

**Wichtig:** Der Updater kann die Dateien im laufenden Betrieb austauschen. Wenn Windows einen Austausch aufgrund laufender Programme sperrt, wird der Versuch protokolliert und später wiederholt. Plane Upgrades vorzugsweise in wartungsarmen Zeiten. Ein laufender separater Discord-Bot muss nach einem Bot-Code-Update ebenfalls neu gestartet werden.

## Einmalige Einrichtung auf dem Windows-Server

1. Lade aus dem Repository **Code → Download ZIP** herunter, und entpacke das ZIP auf dem Server, oder hole die beiden Skripte aus \`tools/\`.
2. Ermittle deinen **server-data-Ordner**, in dem \`resources/[local]/linden_rp/fxmanifest.lua\` liegt. Beispiel: \`C:\FXServer\txData\LindenRP.base\`. **Nicht** den FXServer-Binary-Ordner angeben.
3. Öffne **PowerShell als Administrator**, gehe in den entpackten Repository-Ordner und führe aus:

   \`\`\`powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install-auto-update.ps1 -ServerDataPath 'C:\FXServer\txData\LindenRP.base'
   \`\`\`

   Ersetze den Beispielpfad durch deinen tatsächlichen server-data-Ordner.

4. Starte einen ersten Durchlauf:
   \`\`\`powershell
   schtasks /Run /TN "LindenRP-AutoUpdate"
   \`\`\`
5. Prüfe das Log \`<server-data>\.linden-updater\updater.log\`. Dort steht entweder \`Installed ...\` oder \`no update\` beziehungsweise eine Fehlermeldung.
6. Konfiguriere in txAdmin **Settings → Restarter** eine Zeit für den nächsten automatischen Serverneustart.

## Manuelles Prüfen, ohne Dateien zu verändern

\`\`\`powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\update-linden.ps1 -ServerDataPath 'C:\FXServer\txData\LindenRP.base' -CheckOnly
\`\`\`

## Rollback / Update anhalten

- Updater deaktivieren: \`schtasks /Change /TN "LindenRP-AutoUpdate" /DISABLE\`.
- Wieder aktivieren: \`schtasks /Change /TN "LindenRP-AutoUpdate" /ENABLE\`.
- Rollback bei gestopptem Server: \`resources/[local]/linden_rp\` sichern oder umbenennen, eine ältere Version aus \`.linden-updater/backups\` an den Platz von \`linden_rp\` kopieren, und \`installed-commit.txt\` entfernen. Den Updater zunächst deaktiviert lassen, da er sonst wieder auf den neuesten Commit aktualisiert.

## Grenzen und Sicherheitsregeln

- Aktualisiert **nur** \`linden_rp\`. **Keine** Updates für \`ox_lib\`, ESX, oxmysql, FivePRS, kostenpflichtige Scripts, Datenbanken, \`server.cfg\` oder den separat laufenden Discord-Bot-Prozess.
- Änderungen an der **Recipe** gelten nicht rückwirkend für einen bereits installierten Server.
- Datenbankmigrationen oder inkompatible Änderungen müssen weiterhin bewusst geprüft werden.
- Der Windows-Task läuft als **SYSTEM**. Verwende diese Automatisierung nur auf einem Server, den du administrierst und dessen GitHub-Repository und Commits du kontrollierst. Schütze dein GitHub-Konto mit 2FA: Ein fremder Commit auf main würde beim nächsten Neustart als FiveM-Code ausgeführt.
- Ein automatischer Download ersetzt **keine Live-Tests**. Das Projekt bleibt ein Teststand.
- Das Setup wurde hier strukturell erstellt, aber **nicht auf deinem Windows-Server ausgeführt oder gegen txAdmin live getestet**.

# Korrekturpaket 1 — 28.10.2026

Basis: `6d6c69bb52741c5f635fa654e3f1378202b9f742`.
Status: lokal implementiert und simuliert getestet; keine Installation auf dem
laufenden Server, kein Merge auf main, keine Datenbankänderung.

| Priorität | Nachweis | Korrektur |
|---|---|---|
| Kritisch | ESX 1.16.3 erkennt installierte, aber gestoppte Multichar-Ressource als aktiv. Server registriert den Join nur lokal; Log: `esx:onPlayerJoined was not safe for net`. | Hash-geprüfter Offline-Patch setzt ESX-Multichar/Identity aus; normaler ESX-Account-Join wird verwendet. |
| Kritisch | FivePRS ruft ohne gespeicherte Position `spawnPlayer()` ohne Punkt auf. Leere Spawnliste führt im installierten spawnmanager vor der Nullprüfung zu `spawn.skipFade` auf nil. | ESX übernimmt den ersten Spawn; FivePRS verzichtet in diesem Modus auf seinen Callback und LastLocation-Teleport. Im Standalone-Pfad expliziter Fallback innerhalb bestehender FivePRS-Logik. |
| Hoch | ESX wartet unbefristet auf `skinchanger:loadSkin`; skinchanger fehlt in Startkonfiguration. | Vorlage startet skinchanger vor ESX. Patch prüft Ressourcenstatus, behandelt leere neue Skins, begrenzt Callback auf 10 Sekunden und beendet den Lifecycle bei Fehler. |
| Hoch | Alter Updater verschiebt aktive Ressource vor kontrolliertem Neustart. | Task staged nur; Aktivierung mit exakter SHA und Offline-Prüfung, Backups, Journal, automatische Rücksicherung und expliziter Rollback. |
| Mittel | NUI-Fokuscleanup hing am falschen Ressourcenstopp-Ereignis; KeepInput blieb unberücksichtigt. | `onClientResourceStop` schließt eigene Oberfläche, gibt Fokus und KeepInput frei; doppelte Close-Aufrufe greifen nicht in fremden Fokus ein. |
| Mittel | Tests importieren `../bot`, obwohl Code unter `linden_rp/bot` liegt. | Importpfade und npm-Testkommando korrigiert; 14 bestehende Tests ausführbar. |

Neue `/linden_spawn_diag`-Diagnose beobachtet einmal nach 45 Sekunden und auf
Anforderung Netzwerk, Spawn-Ereignisse, Fade, Ladebildschirm, Kamera und Fokus.
Keine Fade-Schleife, keine zusätzliche Spawnlogik, keine Teleport-Recovery.

Die tatsächliche Bildschirmursache eines konkreten Clients ist ohne F8-Log
weiterhin nicht vollständig belegt. Die Codefehler sind isoliert und ihre
Korrekturen im Lua-Harness nachgestellt. Linden Dispatch ist initial ausgeblendet;
ein dauerhaftes Join-Overlay wurde im gelesenen Code nicht nachgewiesen.

Der Kompatibilitätspatch liegt außerhalb von `linden_rp`, da die betroffenen
Fremdressourcen nicht im Repository liegen. Ein Ressourcenupdate allein behebt
den Server daher nicht. Schritte und bytegenaue Backups: [compat/README.md](compat/README.md).

Weitere Live-Befunde: ESX 1.16.3, FivePRS 0.9.0-ptb.5, MariaDB 10.4.32.
FivePRS dokumentiert MariaDB 10.6+; diese Abweichung muss separat geprüft werden.
Serverlisting meldet Erreichbarkeitsfehler auf Port 30120; das ist ein eigener
Netzwerkbefund und kein Beweis für die schwarze Anzeige nach erfolgreichem Join.
Frühere mapmanager-/sessionmanager-Fehler fehlen im letzten gelesenen Startblock.

Dieser Bericht ist kein abgeschlossener vollständiger Sicherheits-/Codeaudit.
Framework-Schreibsynchronisierung und produktive Rechtevergabe bleiben ausstehend.

# Spawn-Kompatibilität: ESX 1.16.3 / FivePRS 0.9.0-ptb.5

Die JSON-Datei enthält die geprüften Originale und die vollständigen Ersatztexte
für vier Dateien. Der Patch ist bewusst auf diese installierten Dateiversionen
beschränkt. Abweichende lokale Änderungen oder andere Releases werden abgewiesen.
Es gibt keine automatische Bearbeitung laufender Fremdressourcen.

## Entscheidung

ESX besitzt die Account-Session und den ersten Spawn einschließlich Position,
Skin-Callback, Freeze und Fade. ESX-Multicharacter und ESX-Identity sind deaktiviert;
Linden/FivePRS behalten die RP-Charakteroberfläche. Dies ist keine vollständige
Synchronisierung der beiden Charakterdatenmodelle.

FivePRS registriert bei `setr linden_spawn_owner "esx"` keinen Autospawn-Callback.
Es quittiert `FivePRS:Local:SpawnTarget` als extern behandelt, damit das zu dieser
Version gehörende `LastLocation.cs` ESX nicht nachträglich auf eine andere Position
teleportiert. Der vorhandene `playerSpawned`-Zustand bleibt erhalten.

Im Standalone-Modus verbleibt die Spawnsteuerung in FivePRS. Seine bisherigen
leeren `spawnPlayer()`-Aufrufe erhalten eine explizite Position mit gültigem
Freemode-Modell. Vorhandene gespeicherte Positionen werden weiterhin verwendet.

## Anwendung nur nach gesonderter Serverfreigabe

1. Testserver offline nehmen; txAdmin-Neustartaufsicht für das Wartungsfenster
   unterbrechen. Der Patch startet oder stoppt keine Dienste.
2. Vollständiges Datei- und Datenbankbackup erstellen. Bei früherer Nutzung von
   ESX-Multicharacter die Identifier-Struktur der vorhandenen Benutzer prüfen;
   dieser Patch konvertiert keine Daten und kann keine alten `charN:`-Konten
   automatisch einem ESX-Einzelkonto zuordnen.
3. Mit Python 3.10+ zunächst nur prüfen:
   `python tools/patch_spawn_compat.py <ServerDataPath>`
4. Nach erfolgreicher Prüfung:
   `python tools/patch_spawn_compat.py <ServerDataPath> --apply --server-stopped`
   Originalbytes werden vorher unter `.linden-compat/<UUID>/resources/...`
   gesichert. Bei einem Schreibfehler erfolgt die Rücksicherung der angefassten
   Dateien. Wiederholtes Anwenden ist ohne weitere Änderungen möglich.
5. Die bestehende `server.cfg` separat sichern und manuell ergänzen:
   `setr linden_spawn_owner "esx"` sowie `ensure skinchanger` vor `ensure es_extended`.
   `mapmanager`, `sessionmanager`, `esx_multicharacter`, `esx_identity` bleiben aus.
   Geheimnisse nicht durch die Repository-Vorlage ersetzen.
6. Testserver kontrolliert starten; Erstbeitritt, Reconnect, Charakterwechsel,
   Tod/Wiederbelebung und M-Tablet testen. `/linden_spawn_diag` liefert F8-Daten.

Der Ressourcen-Updater installiert diesen Patch NICHT. Auch ein Recipe-Neuaufbau
benötigt den Offline-Schritt; das Recipe lädt ESX derzeit von einem beweglichen
Branch. Bei einem Versionskonflikt stoppen und den Patch neu prüfen lassen.

Ein fehlender oder ablehnender Skin-Callback beendet den ESX-Ladevorgang nach
höchstens zehn Sekunden mit Diagnosemeldung. Ein leerer Skin eines neuen Kontos
erhält `sex=0`. Bestehende ungültige Skins werden nicht als erfolgreicher Spawn
ausgegeben. Es gibt keine pauschale Fade- oder Teleport-Recovery.

## Quellen und Lizenzen

ESX-Dateien stammen aus der gelesenen Installation (Manifest: 1.16.3),
SPDX GPL-3.0-only, Copyright ESX Framework 2022–2026.
[Upstream und Lizenz](https://github.com/esx-framework/esx_core).
Die Join-Testfixtures behalten ihre SPDX-Vermerke.

FivePRS-Spawncode stammt aus der gelesenen Installation 0.9.0-ptb.5;
AGPL-3.0-or-later, FivePRS contributors.
[Versionierter Quellcode](https://github.com/FivePRS/core/tree/v0.9.0-ptb.5).
Die root-LICENSE enthält die AGPL. Die JSON-Originaltexte dienen der
Versionsprüfung und der überprüfbaren Darstellung der Anpassungen.

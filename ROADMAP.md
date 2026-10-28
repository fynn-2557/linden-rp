# Nächste Aufgaben

## Übergabe für 29.10.2026

Die Arbeit wurde auf Nutzerwunsch nach Sicherung beendet. Morgen zuerst
[FORTSETZUNG_MORGEN.md](FORTSETZUNG_MORGEN.md) lesen. Phase 2 wurde ausschließlich
lesend vorbereitet: alle vier Patchdateien passen zu den installierten Originalen,
Testports 30220/40220/3307/4793 waren frei und der bestehende Auto-Updater war
deaktiviert. Es wurde keine Testinstanz eingerichtet und keine Serveränderung
freigegeben. Zielpfade, unabhängige Test-DB und Zugangskonzept finalisieren,
anschließend ausdrückliche Installationsfreigabe einholen.

Wichtige Planungsgrenze: Patch-Installer und Updater verweigern aktuell global
laufende FXServer-Prozesse. Die Produktion darf deshalb nicht für die parallele
Testvorbereitung gestoppt werden; Testdateien lokal offline patchen und ausschließlich
in die getrennte Testkopie übertragen. Keine Schutzprüfung blind umgehen.

## Nach der Übergabe weiterzuverfolgen

1. Korrekturpaket reviewen und separat freigegebene Testserverinstallation mit
   Backups durchführen. Erstbeitritt/Reconnect über Clientlogs bestätigen.
2. Alte Server-Updaterkopie und Task nach eigener Freigabe durch Stage-Version
   ersetzen. Echte Aktivierung/Recovery testen; ggf. dedizierten Start-Interlock
   mit der tatsächlich eingesetzten txAdmin-/Bot-Prozessaufsicht entwickeln.
3. Linden-/FivePRS-Charakter-ID, Erscheinungsbild, Dienst- und Rollenrechte über
   nachgewiesene serverseitige FivePRS-APIs konsolidieren. Native XP-Rechte und
   Department-ACE prüfen; kein UI-Verstecken als Berechtigungsersatz.
4. Identity-API bei Timeout, ungültigem JSON und Reconnect/Source-Wiederverwendung
   härten; asynchrone Antworten an die konkrete Spielersitzung binden.
5. Dispatch-Ereignisse anhand tatsächlicher FivePRS-Schnittstellen anbinden;
   doppelte Einsatzverwaltung verhindern. QB/QBX-Adapter separat testen.
6. MariaDB 10.4.32 gegenüber FivePRS-Anforderung 10.6+ und Port-30120-Listingfehler
   untersuchen. Kein produktives DB-Upgrade ohne Backup und Zustimmung.
7. Profiler-/Resmon-Baseline im laufenden Spiel erstellen; danach gezielt
   Polling, UI-Updates, Datenbankabfragen und Netzwerkaufkommen optimieren.
8. Ausbildung/BF/FF/Rettungsdienst sowie rcore/Zea/LoveRP-Integrationen in kleinen
   getesteten Folgepaketen ausbauen. Vollständigen Code-/Sicherheitsaudit abschließen.

Kein Punkt erfordert oder erlaubt automatisch einen Merge auf main oder eine
Änderung des laufenden Servers.

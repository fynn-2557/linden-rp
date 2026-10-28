# Nächste Aufgaben

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

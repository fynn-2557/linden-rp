# Integrationsstand

| Komponente | Stand nach Korrekturpaket |
|---|---|
| ESX 1.16.3 | Primärer Account-/Erstspawn-Verwalter; Offline-Kompatibilitätspatch vorbereitet und simuliert getestet, nicht live installiert. |
| skinchanger 1.16.3 | Startreihenfolge ergänzt; Callback-Erfolg, Ablehnung, Ausfall und Timeout simuliert. |
| FivePRS 0.9.0-ptb.5 | Bestehende `FivePRS:Local:SpawnTarget`/`SpawnHandled`-Übergabe anhand versioniertem `LastLocation.cs` geprüft. ESX-Modus verhindert Doppelspawn und zweiten Positions-Restore. |
| Linden Characters | Tablet/M und bestehende Daten bleiben erhalten. Vollständige Synchronisierung von Linden- und FivePRS-Charakter-IDs/Aussehen/Rollen steht aus. |
| Linden Dispatch | Vorhandene 11 Exports statisch geprüft; Fokusfreigabe ergänzt. Kein live getesteter Abgleich der FivePRS-Einsätze. |
| ESX/QB/QBX-Bridge | ESX bleibt gewählt, native Jobschreibsynchronisierung bleibt aus. QB/QBX nicht als live validiert ausgewiesen. |
| Discord-Bot/API | 14 bestehende Node-Tests bestehen nach Pfadkorrektur. Kein produktiver Bot-Aufruf und keine Migration. |
| Windows-Updater | Stage/Activate/Rollback lokal unter PS7 und PS5.1 getestet; Serverkopie und Windows-Task müssen separat freigegeben aktualisiert werden. |
| rcore/Zea/LoveRP/pma-voice | Keine neue Integration oder Kompatibilitätszusage; installierte APIs vor separater Arbeit prüfen. |

Die Rollenrechte aus Linden und native FivePRS-Rang-/XP-Rechte sind noch keine
einheitliche Autorität. Die eingeschaltete Department-ACE-Brücke allein ersetzt
keinen vollständigen FivePRS-Rechteadapter. Native Job-Synchronisierung erst nach
entsprechenden Autorisierungs- und Dienststatus-Tests aktivieren.

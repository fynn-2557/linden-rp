# Aktueller Entwicklungsstand – Version 0.3

| Bereich | Status | Hinweis |
|---|---|---|
| Discord Erstantrag, Teamprüfung, einmalige DM-Codes | Implementiert (Prototyp) | Erfordert echten Discord-Test |
| Weitere Behörden und Zivilist nach erster Grundausbildung | Implementiert (Prototyp) | Vom Team genehmigt |
| Einlösen, Haupt-/temporäre Charaktere und sichere Ranggrenzen | Implementiert (Prototyp) | Eigenes SQLite-System, **nicht** FivePRS-Core |
| NRW-Ränge in eigener Charakter-App | Implementiert | Police/Fire/EMS basierend auf deutschen Bezeichnungen |
| FivePRS-Rangnamen visuell übersetzen (native XP bleibt aktiv) | Patch-Skript vorhanden | Ändert Anzeigenamen; XP-Mechanik und Backend-Authentisierung bleiben aktiv |
| Probezeit 7 Tage + drei abgeschlossene Dienste | Implementiert als serverseitige Zustandsmaschine | Vollautomatische FivePRS-Verknüpfung **noch offen** |
| FF-Mitgliedschaft für Zivil-Hauptcharakter | Implementiert als serverseitiges Datenmodell | Aufnahme/Einweisung/Führungsfreigabe als Discord-Verwaltungsaktionen |
| Führungsqualifikation `gruppenfuehrer` und gesonderte FF-Freigabe | Implementiert (Minimalregel) | Qualifikationskatalog muss erweitert werden |
| Dienstbeginn/-ende aus FivePRS automatisch erkennen | **Nicht implementiert** | Dafür müssen tatsächliche FivePRS-Server-Hooks/fork bereitgestellt werden |
| RCore-Skinlesen/-laden | Client-Adapter implementiert | Kein Live-Test, externe Ressource fehlt |
| Native FivePRS-Charaktere, Dienstgrade, Dienstzustand und Akten | **Nicht synchronisiert** | Core-Fork nötig; UI ausblenden ist nicht sicherheitswirksam |
| Linden Dispatch Leitstelle | In ein `linden_rp`-Resource zusammengeführt | Bestehende Web-UI, SQL, Notrufe, AAO, Fahrzeugstatus, Exports; nicht live getestet |
| Dispatcher-Exporte und Serverevents | Implementierter Prototyp | Neue Exports für FMS/Alarmierung/Einsatzabschluss/Backup u. a.; tatsächliche Kompatibilität testen |
| Zea- und LoveRP-Integration | Adapter ausstehend | Externe Ressourcen fehlen, keine erfundenen Events/Exports |
| Discord-Bot | Im selben Ordner, separater Node-Prozess | Als FXServer-Resource selbst nicht ausführbar; der Bot läuft separat |

## Sicherheitstechnisch offen

- FivePRS PTB.5 hat eine **eigene** serverseitige Charakter- und Rangdatenbank. Die Bridge stellt diese nicht ab. Die mitgelieferte Characters-App kann die nativen FivePRS-Pfade **nicht** vollständig ersetzen.
- Das bereitgestellte `startDuty()`/`stopDuty()`-Interface muss ein **vertrauenswürdiger FivePRS-Serveradapter** aufrufen. Es existiert noch kein geprüfter nativer PTB.5-Diensthook. **Zähle auf dem Live-Server keine Probezeit-Dienste, bevor diese Integration umgesetzt und getestet wurde.**
- `/rp_rank` trägt bisher einen administrativen Rangwert ein; verbindliche Qualifikations- und Leistungsprüfungen für alle NRW-Beförderungen sind noch keine vollständige technische Pflichtprüfung.
- RCore darf nicht automatisch eine nicht genehmigte Dienstuniform oder Sonderfunktion freischalten; dafür sind Uniform- und Berechtigungsadapter geplant.
- ACE-Teilzugriff in FivePRS reicht nicht für das Einfrieren eines kompletten Berufs-Charakters oder die dauerhafte Bindung von FivePRS-Einsätzen an die RP-Identität.
- `rcore_clothing` und andere Drittanbieter-Ressourcen sind nicht in dieser ZIP enthalten.

**Status:** Lokale automatisierte Unit-Tests bestanden. Keine realen FiveM-, Discord-, RCore- oder Mehrspieler-Livetests.

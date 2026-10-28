# Tests vor echtem Serverbetrieb

## Bereits automatisiert

- Erstbewerbung: Zivilist verboten, nur eine offene Erstbewerbung
- Genehmigung: einmaliger persönlicher Einlösecode, keine zweite Verwendung, Lizenzbindung
- Weitere Rolle erst nach der ersten bestandenen Grundausbildung
- Temporäre Charaktere erst nach Ausbildung und nur unter persönlichem Höchstrang
- Beförderungsänderung reduziert überhöhte Rangwerte temporärer Charaktere
- RP-Reset entfernt temporäre Charaktere, aber nicht die Hauptcharaktere
- Verschiedene Charakter-Outfits werden getrennt gespeichert
- HTTP-API erfordert Authentisierung
- NRW-Ranglisten statt amerikanischer Dienstgrade
- Probezeit: drei **abgeschlossene** Dienste; keine Zeituntergrenze; keine doppelte Zählung
- Probezeitabschluss frühestens nach sieben Tagen
- FF: Aufnahme/Einweisung/Führungsfreigabe mit Feuerwehr- und Zivilcharakter

## Live vor Freigabe prüfen (noch NICHT getestet)

1. Discord DM-Verbot, fehlende Berechtigungen und mehrfaches Drücken der Genehmigungsbuttons.
2. FiveM `discord:`-Identifier mit tatsächlich verbundenem Discord-Client, Lizenzbindung beim ersten Login.
3. `M` Tablet öffnen: Keine Konflikte mit FivePRS, rcore oder anderen Keymappings.
4. Code aus DM einmalig einlösen, zweite Behörde einlösen, Haupt-/temporäre Charaktere wählen.
5. Kleidung im RCore-Wechsel speichern, vier verschiedene Charaktere ohne Skin-Leck testen.
6. **FivePRS nativer Duty-Hook**: Dienstbeginn/-ende autoritativ auslesen und Server-Export anrufen; unerwartete Disconnects dürfen nicht fälschlich als Dienst zählen.
7. Ein Zivilcharakter ohne FF-Freigabe darf im echten FivePRS keine Fire-Uniform/Fahrzeuge über den eingebauten Duty-Flow bekommen.
8. UI-Patch der alten Characters-App: native FivePRS-Endpunkte separat mit sicherem Core-Fork abschalten.
9. Serverneustart mit SQLite-Datenbank: Haupt- und temporäre Charaktere bleiben erhalten. Team-Reset entfernt nur temporäre.
10. Mehrere Spieler gleichzeitig, Serverwechsel, Rate-Limit, Race Conditions, Admin-Rechte und Replay-Versuche.

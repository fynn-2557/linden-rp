# Linden RP NRW — verbindliche Architekturleitlinien

Diese Leitlinien übernehmen die am 28.10.2026 bereitgestellte Projektvision.
Sie ergänzen KONZEPT_NRW.md; vorhandene fachliche Regeln bleiben maßgeblich.

| System | Verantwortung |
|---|---|
| `linden_rp` | Eine modular aufgebaute eigene Hauptressource für Identität, RP-Rechte, Behörden, Dienstlogik, Bridges und Linden Dispatch. |
| FivePRS | Bestehende BOS-Spielmechanik, NPC-Interaktionen und Tablet als eigenständige Abhängigkeit. |
| ESX Legacy | Aktuelles technisches Spielerframework. Im Korrekturpaket besitzt ESX den ersten Spawn; das verleiht ESX keine fachliche Autorität über Linden-Ränge oder RP-Charaktere. |
| Linden Dispatch | Zielsystem für Einsätze, Disposition, AAO, Funk-/Pager-Anbindungen und Journale. FivePRS-Einsätze werden kontrolliert angebunden, nicht unabhängig doppelt erzeugt. |
| Discord-Bot | Bewerbungen, geprüfte Freigaben und einmalige persönliche Codes; Einlösung in der Characters-App. |
| ox_lib / oxmysql | Gemeinsame Hilfsfunktionen und Datenbankzugriff. |

## Fachliche Invarianten

- NRW-orientiertes Behörden-RP in einer fiktiven deutschen Stadt samt Umland;
  kein Grind und keine automatische Beförderung durch XP, Geld oder Spielzeit.
- Linden entscheidet serverseitig über RP-Rechte. Native FivePRS-/Framework-
  Mechanismen dürfen darüber hinaus keine unkontrollierten Rechte freigeben.
- Erstbewerbung für Polizei, Feuerwehr oder Rettungsdienst; weitere Freigaben
  nach Konzept. Pro genehmigter Organisation ein dauerhafter Hauptcharakter
  mit Stern, eigene Identität, Ausbildung, Diensthistorie und Erscheinungsbild.
- Temporäre Charaktere bleiben über gewöhnliche Neustarts erhalten und dürfen
  weder die freigegebenen Ränge noch Führungs-/Sonderrechte überschreiten.
- Charakterverwaltung im FivePRS-Tablet, Schnellzugriff M, kein verpflichtendes
  `/character`. Kein Wechsel während aktiven Dienstes.
- Grundausbildung vor eigenständigem regulärem Dienst; danach mindestens sieben
  Tage, drei abgeschlossene Dienste und eine befugte abschließende Beurteilung.
  Dienste besitzen keine feste Mindestdauer.
- Polizei mit GE/K/V/ZA; BF und FF mit getrennten Laufbahnen und gemeinsamer
  oberster Feuerwehrleitung. Spezialqualifikationen sind unabhängig vom Rang.
  FF-Zugang über genehmigten Zivilcharakter und gesonderte Freigaben/Einweisung.
- Rettungsdienst bleibt eigenständig geführt; medizinische Qualifikation und
  organisatorische Führungsrechte sind getrennt. Gemeinsame integrierte
  Leitstelle für Feuerwehr/Rettungsdienst, Polizei kann eigene Struktur haben.

## Technische Grenzen und Entwicklung

Ein aktives Spielerframework pro Instanz. QB-/QBX-Unterstützung erfordert
gezielte nachgewiesene Adapter und Tests. Externe kommerzielle Ressourcen
(rcore, Zea, LoveRP) werden weder mitverteilt noch über erfundene APIs angebunden.
Vorhandene funktionierende FivePRS-Spielmechanik bleibt nutzbar.

UIs sind funktional, überwiegend deutsch und an Behörden-/Leitstellenabläufen
orientiert. Kein dauerhaft blockierendes Join-Overlay. Die interne Modularität
wird ausgebaut, ohne unnötige zusätzliche Hauptressourcen anzulegen.

Aktuell gilt Stabilität vor Funktionsumfang. Das erste Paket begrenzt sich auf
Join/Spawn, Fokuscleanup und sicheren Updatebetrieb. Die vollständige Charakter-,
Dienst- und Rechtekonsolidierung ist weiterhin offen und darf erst nach echten
Integrationstests als abgeschlossen gelten. Siehe INTEGRATION_STATUS.md und ROADMAP.md.

Entwicklung erfolgt auf Feature-Branches mit reviewbaren Pull Requests. Kein
Merge auf main, kein produktiver Datenbankeingriff und keine Änderung laufender
Serverdienste ohne separate ausdrückliche Freigabe. Der bestehende Auto-Updater
überwacht main; ein Draft-PR ist kein Deployment.


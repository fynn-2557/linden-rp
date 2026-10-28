# Performance — tatsächlich geprüft

Keine Live-Resmon-/Profiler-Messung und kein belastbarer Vorher/Nachher-FPS-
Vergleich verfügbar. Auf dem laufenden Server wurden weder Befehle ausgeführt
noch Ressourcen geändert. Es werden keine verbesserten Laufzeitwerte behauptet.

Die gelesenen Serverlogs enthalten vereinzelte Startup-Hitches von 174 bis
288 ms. Das ist keine Messung des laufenden Spielbetriebs und erlaubt keine
Zuordnung zu einer einzelnen Ressource.

Im Code verifizierte Eigenschaften:

- Die Spawn-Diagnose ergänzt genau einen einmaligen 45-Sekunden-Wait; keine
  permanente Schleife und keine zusätzlichen Server-/NUI-Nachrichten.
- Im ESX-Modus registriert FivePRS keinen eigenen Autospawn-Callback. Die
  konkurrierende Erstspawn-Wartephase entfällt für diesen Pfad.
- Fehlender Skin-Callback war vorher unbeschränkt; jetzt nach spätestens
  10 Sekunden Fehlerabschluss im simulierten Ablauf. Das ist eine obere
  Wartezeitgrenze, kein gemessener normaler Join-Zeitgewinn.
- Identisches bereits gestagtes Release wird geprüft und wiederverwendet;
  wiederholter Tasklauf erzeugt im Test keine zweite Staging-Kopie.
- Vollständige Hashprüfung und Kopie von Laufzeitdaten finden bei Aktivierung
  im Wartungsfenster statt. Größe von node_modules/Logs kann die Dauer erhöhen.

Nach gesonderter Testserverfreigabe: identische Spielerzahl und Szenarien für
Erstbeitritt, Reconnect, Tablet idle/offen, Charakterwechsel und Dispatch-Last
verwenden; Client-Resmon und Server-Profiler davor/danach erfassen. Lua-Harness-
Zeiten sind keine Ersatzmessung für FiveM.

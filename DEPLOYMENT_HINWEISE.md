# Deployment und Grenzen v0.4

- Standard: ESX Legacy + ox_lib + oxmysql, eine **aktive** Framework-Instanz.
- Alternative: `set linden_framework "qb"` mit **manuell** installiertem qb-core oder `qbx` mit qbx_core; nicht ESX und QB gleichzeitig starten.
- `linden_rp` bleibt die einzige projektinterne FiveM-Ressource.
- FivePRS (Testbuild) muss als **separate** Ressource mit kompatiblen binären Releases installiert werden. Lizenz beachten.
- ox_lib und ESX können automatisch über txAdmin heruntergeladen werden; `rcore_clothing`, Zea und LoveRP sind externe, teils kommerzielle Scripts und werden nicht mitverteilt.
- Ein txAdmin-Recipe kann **keinen Discord-Bot als Windows-Dienst starten**. `linden_rp/bot` braucht eine separate Node.js-Laufzeit/Prozessaufsicht und eigene `.env`-Datei.
- `linden_sync_native_jobs` ist aus Sicherheitsgründen standardmäßig `false`. Die Discord-Freigabe entscheidet über den RP-Job; native Framework-Jobs können erst nach manuellem Anlegen und End-to-End-Test synchronisiert werden.
- Diese Bridge bietet stabile APIs (`GetCanonicalJob`, `GetFrameworkMode`, `GetNativeJob`, `HasLindenJob`). ESX-/QB-exklusive Dritt-Scripts müssen bei Bedarf direkt auf den Bridge-Export umgestellt werden; pauschale 100%-Kompatibilität kann nicht garantiert werden.
- Für txAdmin muss die vollständige Ressource unter einer für den Server erreichbaren GitHub-URL veröffentlicht sein (oder es wird manuell installiert). Eine Sandbox-URL in ChatGPT reicht nicht.
- Dieses Paket wurde nur lokal statisch und mit vorhandenen Node-Tests geprüft, **nicht** auf einem FiveM-Liveserver.

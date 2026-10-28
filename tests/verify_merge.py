from pathlib import Path
root=Path(__file__).resolve().parents[1]/'linden_rp'
manifest=(root/'fxmanifest.lua').read_text()
assert "ui_page 'web/index.html'" in manifest
for f in ['client/main.lua','client/identity.lua','server/main.lua','server/identity.lua','web/index.html','html/index.html','bot/main.js']:
    assert (root/f).is_file(),f
for name in ['CreateIncident','GetIncident','GetVehicleStatus','SetVehicleStatus','RegisterVehicle','DispatchVehicle','RequestBackup','SendPagerAlert','SendRadioMessage','GetAvailableUnits','CloseIncident']:
    assert f"exports('{name}'" in (root/'server/main.lua').read_text(),name
assert 'Config.TrustedResources' in (root/'dispatch_config.lua').read_text()
assert 'IdentityConfig.ApiSecret' in (root/'server/identity.lua').read_text()
assert 'Config.Framework' in (root/'server/main.lua').read_text()
print('Zusammenführung: Dateien, 11 Exports und Namensräume geprüft.')

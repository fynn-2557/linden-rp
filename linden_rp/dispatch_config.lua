Config = {}
Config.Framework = GetConvar('linden_framework','esx') -- ESX default, QB/QBX optional; authorization still derives only from Linden identity
Config.DefaultLanguage = 'de'
Config.CreatorAce = 'linden.creator'
Config.DispatcherAce = 'linden.dispatcher'
Config.AdminGroups = { admin = true, superadmin = true, god = true }
Config.DispatcherJobs = { leitstelle = true, dispatcher = true }
Config.AllowedServiceJobs = { police = true, ambulance = true, fire = true, feuerwehr = true, rettungsdienst = true }
Config.EmergencyNumbers = { ['112'] = true, ['110'] = true }
Config.Cooldowns = { call = 30, message = 2, status = 2, panic = 30 }
Config.CallTextMaxLength = 550
Config.AutoArrival = false
Config.AutoArrivalDistance = 75.0
Config.AutoArrivalIntervalSeconds = 20
Config.ReleaseUnitWhenDisconnected = true
Config.RequireConfiguredVehiclePlate = true
Config.Voice = 'auto' -- Currently only pma-voice radio channel switching implemented
Config.DiscordWebhook = '' -- empty = no outbound requests
Config.ShowMapSchematicNotice = true
Config.InitialOrganizations = {
  { name = 'Feuerwehr', short = 'FW', color = '#e86748', job = 'fire' },
  { name = 'Rettungsdienst', short = 'RD', color = '#52a8c5', job = 'ambulance' },
  { name = 'Polizei', short = 'POL', color = '#7995de', job = 'police' }
}
Config.DefaultKeywords = {
  { name = 'F1 – Kleinbrand', org = 'Feuerwehr', aao = 'HLF:1' },
  { name = 'B3 – Gebäudebrand', org = 'Feuerwehr', aao = 'HLF:2,DLK:1,ELW:1,RTW:1' },
  { name = 'H1 – Hilfeleistung', org = 'Feuerwehr', aao = 'HLF:1' },
  { name = 'R1 – Notfall', org = 'Rettungsdienst', aao = 'RTW:1' },
  { name = 'P1 – Polizeieinsatz', org = 'Polizei', aao = 'FuStW:1' }
}
Config.StatusLabels = {
  ['0'] = 'Prioritätsruf', ['1'] = 'Einsatzbereit Funk', ['2'] = 'Einsatzbereit Wache',
  ['3'] = 'Einsatz übernommen', ['4'] = 'Am Einsatzort', ['5'] = 'Sprechwunsch',
  ['6'] = 'Nicht einsatzbereit', ['7'] = 'Patient aufgenommen', ['8'] = 'Transportziel erreicht'
}

-- External server resources must be explicitly approved before calling dispatch exports.
-- Enable integrations only after testing their actual APIs.
Config.TrustedResources = {
  -- ['z_fire'] = true,
  -- ['my_test_script'] = true,
}

-- Console-only smoke test. Never sends vehicle alerts or runs an AAO.
Config.TestMode = GetConvar('linden_rp_test_mode', 'false') == 'true'

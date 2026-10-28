IdentityConfig = {}
IdentityConfig.ApiBase = GetConvar('rp_identity_api', 'http://127.0.0.1:4792')
IdentityConfig.ApiSecret = GetConvar('rp_identity_api_secret','')
IdentityConfig.EnableWhitelist = GetConvar('rp_identity_whitelist', 'true') == 'true'
IdentityConfig.CooldownMs = 600
IdentityConfig.EnableFivePrsAce = GetConvar('rp_identity_fiveprs_ace','true') == 'true' -- ACE bridge only, native FivePRS rank/character records remain separate

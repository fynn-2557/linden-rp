-- ESX is the selected primary framework. QB/QBX are alternative modes, not parallel databases.
FrameworkConfig = {
    Mode = GetConvar('linden_framework', 'esx'),  -- esx | qb | qbx | standalone
    SyncNativeJobs = GetConvar('linden_sync_native_jobs', 'false') == 'true',
    -- Map approved Linden roles to registered native framework jobs (must exist upstream).
    JobNames = { police = 'police', fire = 'fire', ems = 'ambulance', civilian = 'unemployed' },
    OffDutyJob = 'unemployed',
    -- Native job grade 0 avoids accidentally granting native boss privileges.
    DefaultGrade = 0,
}

-- ox_lib notification shim; scripts can use the central bridge rather than guessing ESX/QB.
RegisterNetEvent('linden_rp:bridge:notify',function(message,notifyType)
    if type(message)~='string' then return end
    if lib and lib.notify then
        lib.notify({title='Linden RP',description=message:sub(1,300),type=notifyType or 'inform'})
    end
end)
exports('Notify',function(message,notifyType)
    if lib and lib.notify then
        lib.notify({title='Linden RP',description=tostring(message),type=notifyType or 'inform'})
    end
end)

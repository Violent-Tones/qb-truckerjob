local QBCore = exports['qb-core']:GetCoreObject()
local Bail = {}
local ShopsBonusCounter = {}
local bonusCounterByCid = {}

RegisterNetEvent('qb-trucker:server:ShopRestocked', function(shop, cid)
    if ShopsBonusCounter[shop] == nil or cid == nil then return end

    local bonusCounter = 0
    for _,v in pairs(ShopsBonusCounter[shop]) do
        bonusCounter += v
    end
    ShopsBonusCounter[shop] = nil

    if bonusCounterByCid[cid] == nil then
        bonusCounterByCid[cid] = 0
    end
    bonusCounterByCid[cid] += bonusCounter

    SaveResourceFile(GetCurrentResourceName(), Config.ShopsDemandJsonFile, json.encode(ShopsBonusCounter))
end)

RegisterNetEvent('qb-trucker:server:ShopOutOfStock', function(shop, itemSlot, priorityNum)
    if ShopsBonusCounter[shop] == nil then
        ShopsBonusCounter[shop] = {}
    end

    if ShopsBonusCounter[shop][itemSlot] == priorityNum then return end

    ShopsBonusCounter[shop][itemSlot] = priorityNum

    -- Send Notification to players
    CreateThread(function()
        if next(QBCore.Players) then
            for _, Player in pairs(QBCore.Players) do
                if Player then
                    TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, "Truckers Wanted: A shop is low in stock. Increased payment will be awarded for a delivery.", 'primary', 3000)
                end
            end
        end
    end)

    SaveResourceFile(GetCurrentResourceName(), Config.ShopsDemandJsonFile, json.encode(ShopsBonusCounter))
end)

RegisterNetEvent('qb-trucker:server:DoBail', function(bool, vehInfo)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if bool then
        if Player.PlayerData.money.cash >= Config.TruckerJobTruckDeposit then
            Bail[Player.PlayerData.citizenid] = Config.TruckerJobTruckDeposit
            Player.Functions.RemoveMoney('cash', Config.TruckerJobTruckDeposit, 'tow-received-bail')
            TriggerClientEvent('QBCore:Notify', src, Lang:t('success.paid_with_cash', { value = Config.TruckerJobTruckDeposit }), 'success')
            TriggerClientEvent('qb-trucker:client:SpawnVehicle', src, vehInfo)
        elseif Player.PlayerData.money.bank >= Config.TruckerJobTruckDeposit then
            Bail[Player.PlayerData.citizenid] = Config.TruckerJobTruckDeposit
            Player.Functions.RemoveMoney('bank', Config.TruckerJobTruckDeposit, 'tow-received-bail')
            TriggerClientEvent('QBCore:Notify', src, Lang:t('success.paid_with_bank', { value = Config.TruckerJobTruckDeposit }), 'success')
            TriggerClientEvent('qb-trucker:client:SpawnVehicle', src, vehInfo)
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_deposit', { value = Config.TruckerJobTruckDeposit }), 'error')
        end
    else
        if Bail[Player.PlayerData.citizenid] then
            Player.Functions.AddMoney('cash', Bail[Player.PlayerData.citizenid], 'trucker-bail-paid')
            Bail[Player.PlayerData.citizenid] = nil
            TriggerClientEvent('QBCore:Notify', src, Lang:t('success.refund_to_cash', { value = Config.TruckerJobTruckDeposit }), 'success')
        end
    end
end)

RegisterNetEvent('qb-trucker:server:01101110', function(drops)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    drops = tonumber(drops)
    local bonus = 0

    if drops >= 5 then
        if Config.TruckerJobBonus < 0 then Config.TruckerJobBonus = 0 end
        bonus = (math.ceil(Config.TruckerJobDropPrice / 100) * Config.TruckerJobBonus) * drops
    end

    local demandBonus = 0
    if bonusCounterByCid[Player.PlayerData.citizenid] ~= nil then
        demandBonus = bonusCounterByCid[Player.PlayerData.citizenid] * Config.TruckerJobDemandIncrease
        bonusCounterByCid[Player.PlayerData.citizenid] = nil
    end

    local payment = (Config.TruckerJobDropPrice * drops + bonus + demandBonus)
    payment = payment - (math.ceil(payment / 100) * Config.TruckerJobPaymentTax)
    Player.Functions.AddJobReputation(drops)
    Player.Functions.AddMoney('bank', payment, 'trucker-salary')
    TriggerClientEvent('QBCore:Notify', src, Lang:t('success.you_earned', { value = payment }), 'success')
end)

RegisterNetEvent('qb-trucker:server:nano', function()
    local chance = math.random(1, 100)
    if chance > 26 then return end
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
    xPlayer.Functions.AddItem('cryptostick', 1, false)
    TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items['cryptostick'], 'add')
end)

CreateThread(function()
    local shopDemJson = LoadResourceFile(GetCurrentResourceName(), Config.ShopsDemandJsonFile)
    shopDemJson = json.decode(shopDemJson)
    if next(shopDemJson) == nil then return end

    -- Update shops inventory to match json file
    ShopsBonusCounter = shopDemJson
end)

-- Function to check time and trigger event
local function CheckTimeAndTriggerEvent()
    local currentHour, currentMin = exports["qb-weathersync"]:getTime()
    if (currentHour == 6 or currentHour == 12) and currentMin == 0 and ShopsBonusCounter ~= {} and next(QBCore.Players) then
        for _, Player in pairs(QBCore.Players) do
            if Player then
                TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, "Truckers Wanted: A shop is low in stock. Increased payment will be awarded for a delivery.", 'primary', 3000)
            end

        end
        Citizen.Wait(2000)
    end
end

-- Main loop to check time periodically
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Wait for 1 second (adjust as needed)
        CheckTimeAndTriggerEvent()
    end
end)

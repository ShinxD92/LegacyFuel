if Config.UseESX then
	ESX = nil

	Citizen.CreateThread(function()
		while not ESX do
			TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
			Citizen.Wait(100)
		end
	end)
end

local isNearPump = false
local isFueling = false
local currentFuel = 0.0
local currentCost = 0.0
local currentCash = 1000
local fuelSynced = false
local inBlacklisted = false
local disablekeyfuel = true
function ManageFuelUsage(vehicle)
	if not DecorExistOn(vehicle, Config.FuelDecor) then
		SetFuel(vehicle, math.random(200, 800) / 10)
	elseif not fuelSynced then
		SetFuel(vehicle, GetFuel(vehicle))

		fuelSynced = true
	end

	if IsVehicleEngineOn(vehicle) then
		SetFuel(vehicle, GetVehicleFuelLevel(vehicle) - Config.FuelUsage[Round(GetVehicleCurrentRpm(vehicle), 1)] * (Config.Classes[GetVehicleClass(vehicle)] or 1.0) / 10)
	end
end






Citizen.CreateThread(function()
	DecorRegister(Config.FuelDecor, 1)

	for i = 1, #Config.Blacklist do
		if type(Config.Blacklist[i]) == 'string' then
			Config.Blacklist[GetHashKey(Config.Blacklist[i])] = true
		else
			Config.Blacklist[Config.Blacklist[i]] = true
		end
	end

	for i = #Config.Blacklist, 1, -1 do
		table.remove(Config.Blacklist, i)
	end

	while true do
		Citizen.Wait(1000)

		local ped = PlayerPedId()

		if IsPedInAnyVehicle(ped) then
			local vehicle = GetVehiclePedIsIn(ped)

			if Config.Blacklist[GetEntityModel(vehicle)] then
				inBlacklisted = true
			else
				inBlacklisted = false
			end

			if not inBlacklisted and GetPedInVehicleSeat(vehicle, -1) == ped then
				ManageFuelUsage(vehicle)
			end
		else
			if fuelSynced then
				fuelSynced = false
			end

			if inBlacklisted then
				inBlacklisted = false
			end
		end
	end
end)

function FindNearestFuelPump()
	local coords = GetEntityCoords(PlayerPedId())
	local fuelPumps = {}
	local handle, object = FindFirstObject()
	local success

	repeat
		if Config.PumpModels[GetEntityModel(object)] then
			table.insert(fuelPumps, object)
		end

		success, object = FindNextObject(handle, object)
	until not success

	EndFindObject(handle)

	local pumpObject = 0
	local pumpDistance = 1000

	for k,v in pairs(fuelPumps) do
		local dstcheck = GetDistanceBetweenCoords(coords, GetEntityCoords(v))

		if dstcheck < pumpDistance then
			pumpDistance = dstcheck
			pumpObject = v
		end
	end

	return pumpObject, pumpDistance
end

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(500)

		local pumpObject, pumpDistance = FindNearestFuelPump()

		if pumpDistance < 2.5 then
			isNearPump = pumpObject

		else
			isNearPump = false

			Citizen.Wait(math.ceil(pumpDistance * 20))
		end
	end
end)

function DrawText3Ds(x, y, z, text)
	local onScreen,_x,_y=World3dToScreen2d(x,y,z)
	local px,py,pz=table.unpack(GetGameplayCamCoords())

	SetTextScale(0.35, 0.35)
	SetTextFont(4)
	SetTextProportional(1)
	SetTextColour(255, 255, 255, 215)
	SetTextEntry("STRING")
	SetTextCentre(1)
	AddTextComponentString(text)
	DrawText(_x,_y)


	local factor = (string.len(text)) / 470

	DrawRect(_x, _y + 0.0190, 0.040 + factor, 0.055, 41, 11, 41, 100)	

end



function DrawText3Ds22(x, y, z, text)

	local onScreen,_x,_y=World3dToScreen2d(x,y,z)
	local px,py,pz=table.unpack(GetGameplayCamCoords())
	if onScreen then
		SetTextScale(0.34, 0.34)
		SetTextFont(4)
		SetTextProportional(1)
		SetTextColour(255, 255, 255, 215)
		SetTextDropshadow(0, 0, 0, 0, 155)
		SetTextEdge(1, 0, 0, 0, 250)
		SetTextDropShadow()
		SetTextOutline()
		SetTextEntry("STRING")
		SetTextCentre(1)
		AddTextComponentString(text)
        DrawText(_x,_y)
        local factor = (string.len(text)) / 370
        DrawRect(_x,_y+0.0125, 0.018+ factor, 0.03, 41, 11, 41, 100)
	end

end

function LoadAnimDict(dict)
	if not HasAnimDictLoaded(dict) then
		RequestAnimDict(dict)

		while not HasAnimDictLoaded(dict) do
			Citizen.Wait(1)
		end
	end
end

AddEventHandler('LRP-FUEL-gasostartFuelUpTick', function(pumpObject, ped, vehicle)
	currentFuel = GetVehicleFuelLevel(vehicle)

	while isFueling do
		Citizen.Wait(500)

		local oldFuel = DecorGetFloat(vehicle, Config.FuelDecor)
		local fuelToAdd = math.random(10, 20) / 10.0
		local extraCost = fuelToAdd / 1.5

		if not pumpObject then
			if GetAmmoInPedWeapon(ped, 883325847) - fuelToAdd * 100 >= 0 then
				currentFuel = oldFuel + fuelToAdd

				SetPedAmmo(ped, 883325847, math.floor(GetAmmoInPedWeapon(ped, 883325847) - fuelToAdd * 100))
			else
				isFueling = false
			end
		else
			currentFuel = oldFuel + fuelToAdd
		end

		if currentFuel > 100.0 then
			currentFuel = 100.0
			isFueling = false
		end

		currentCost = currentCost + extraCost

		if currentCash >= currentCost then
			SetFuel(vehicle, currentFuel)
		else
			isFueling = false
		end
	end

	if pumpObject then
		TriggerServerEvent('LRP-FUEL-gasopay', currentCost)
	end
	currentCost = 0.0
end)
function Round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)

	return math.floor(num * mult + 0.5) / mult
end

AddEventHandler('LRP-FUEL-gasorefuelFromPump', function(pumpObject, ped, vehicle)
	TaskTurnPedToFaceEntity(ped, vehicle, 1000)
	Citizen.Wait(1000)
	SetCurrentPedWeapon(ped,883325847, true)
	--LoadAnimDict("weapon@w_sp_jerrycan")
	 loadAnimDict("weapon@w_sp_jerrycan")
	TaskPlayAnim(ped, "weapon@w_sp_jerrycan", "fire",  8.0, 1.0, -1, 1, 0, 0, 0, 0 )

	TriggerEvent('LRP-FUEL-gasostartFuelUpTick', pumpObject, ped, vehicle)

	while isFueling do
		Citizen.Wait(1)

		for k,v in pairs(Config.DisableKeys) do
			DisableControlAction(0, v)
		end

		local vehicleCoords = GetEntityCoords(vehicle)

		if pumpObject then
			local stringCoords = GetEntityCoords(pumpObject)
			local extraString = ""

			if Config.UseESX then
				extraString = "[Costo: ~g~$" .. Round(currentCost, 1).."~s~]"
			end
			DrawText3Ds22(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.CancelFuelingPump .. extraString)
			DrawText3Ds22(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5, Round(currentFuel, 1) .. "%")
		else
			DrawText3Ds22(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5, "Bidon gasolina: ~g~" .. Round(GetAmmoInPedWeapon(ped, 883325847) / 4500 * 100, 1) .. "% | Vehiculo: " .. Round(currentFuel, 1) .. "%")
		end
 
		if not IsEntityPlayingAnim(ped, "weapon@w_sp_jerrycan", "fire", 3) then
			TaskPlayAnim(ped, "weapon@w_sp_jerrycan", "fire",  8.0, 1.0, -1, 1, 0, 0, 0, 0 )
		end

		if IsControlJustReleased(0, 38) or DoesEntityExist(GetPedInVehicleSeat(vehicle, -1)) or (isNearPump and GetEntityHealth(pumpObject) <= 0) then
			isFueling = false
		end
	end


	ClearPedTasks(ped)
	RemoveWeaponFromPed(ped,883325847)
	TriggerServerEvent('linden_inventory:removeItem',"WEAPON_PETROLCAN",1)
	SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED') , true)

end)





Citizen.CreateThread(function()
	while true do
		Citizen.Wait(5)

		local ped = PlayerPedId()

		if not isFueling and ((isNearPump and GetEntityHealth(isNearPump) > 0) or (GetSelectedPedWeapon(ped) == 883325847 and not isNearPump)) then
			if IsPedInAnyVehicle(ped) and GetPedInVehicleSeat(GetVehiclePedIsIn(ped), -1) == ped then
				local pumpCoords = GetEntityCoords(isNearPump)

				DrawText3Ds22(pumpCoords.x, pumpCoords.y, pumpCoords.z + 1.2, Config.Strings.ExitVehicle)
			else
				local vehicle = GetPlayersLastVehicle()
				local vehicleCoords = GetEntityCoords(vehicle)

				if DoesEntityExist(vehicle) and GetDistanceBetweenCoords(GetEntityCoords(ped), vehicleCoords) < 2.5 then
					if not DoesEntityExist(GetPedInVehicleSeat(vehicle, -1)) then
						local stringCoords = GetEntityCoords(isNearPump)
						local canFuel = true

						if GetSelectedPedWeapon(ped) == 883325847 then
							stringCoords = vehicleCoords

							if GetAmmoInPedWeapon(ped, 883325847) < 0 then
								canFuel = false

							end
						end

						if GetVehicleFuelLevel(vehicle) < 95 and canFuel then
							if currentCash > 0 then
								DrawText3Ds22(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.EToRefuel)

								if IsControlJustReleased(0, 38) then
									isFueling = true

									TriggerEvent('LRP-FUEL-gasorefuelFromPump', isNearPump, ped, vehicle)
							    	 loadAnimDict("timetable@gardener@filling_can")
									--LoadAnimDict("timetable@gardener@filling_can")
								end
							else
								DrawText3Ds22(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.NotEnoughCash)
							end
						elseif not canFuel then
							DrawText3Ds22(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.JerryCanEmpty)
						else
							DrawText3Ds22(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.FullTank)
						end
					end
				elseif isNearPump then
					local stringCoords = GetEntityCoords(isNearPump)

						if not HasPedGotWeapon(ped, 883325847) then
							if disablekeyfuel == true then
							
								DrawText3Ds22(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.PurchaseJerryCan)
								if IsControlJustReleased(0, 38) then
									 TriggerServerEvent('LRP-FUEL-gasopay2', Config.JerryCanCost)
									 disablekeyfuel = true
									 Wait(2000)
									 disablekeyfuel = true
								end


							end
						else
 
						end

				else
					Citizen.Wait(250)
				end
			end
		else
			Citizen.Wait(250)
		end
	end
end)

function CreateBlip(coords)
	local blip = AddBlipForCoord(coords)

	SetBlipSprite(blip, 361)
	SetBlipScale(blip, 0.8)
	SetBlipColour(blip, 40)
	SetBlipDisplay(blip, 4)
	SetBlipAsShortRange(blip, true)

	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString("Gas Station")
	EndTextCommandSetBlipName(blip)

	return blip
end

if Config.ShowNearestGasStationOnly then
	Citizen.CreateThread(function()
		local currentGasBlip = 0

		while true do
			Citizen.Wait(10000)

			local coords = GetEntityCoords(PlayerPedId())
			local closest = 1000
			local closestCoords

			for k,v in pairs(Config.GasStations) do
				local dstcheck = GetDistanceBetweenCoords(coords, v)

				if dstcheck < closest then
					closest = dstcheck
					closestCoords = v
				end
			end

			if DoesBlipExist(currentGasBlip) then
				RemoveBlip(currentGasBlip)
			end

			currentGasBlip = CreateBlip(closestCoords)
		end
	end)
elseif Config.ShowAllGasStations then
	Citizen.CreateThread(function()
		for k,v in pairs(Config.GasStationsblip) do
			CreateBlip(v)
		end
	end)
end

function GetFuel(vehicle)
	return DecorGetFloat(vehicle, Config.FuelDecor)
end

function SetFuel(vehicle, fuel)
	if type(fuel) == 'number' and fuel >= 0 and fuel <= 100 then
		SetVehicleFuelLevel(vehicle, fuel + 0.0)
		DecorSetFloat(vehicle, Config.FuelDecor, GetVehicleFuelLevel(vehicle))
	end
end

local gasolina = false


function loadAnimDict(dict)

	if not HasAnimDictLoaded(dict) then
	
		RequestAnimDict(dict)
		while ( not HasAnimDictLoaded(dict)) do
			RequestAnimDict(dict)
			Citizen.Wait( 5 )
		end
	
	end 
	
	
	end
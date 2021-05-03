
	local ESX = nil

	TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)



	RegisterServerEvent('LRP-FUEL-gasopay')
	AddEventHandler('LRP-FUEL-gasopay', function(price)
		local xPlayer = ESX.GetPlayerFromId(source)
		local amount = ESX.Math.Round(price)
		local src = source
		local money = xPlayer.getMoney()


			xPlayer.removeMoney(amount)

	end)


RegisterServerEvent('LRP-FUEL-gasopay2')
AddEventHandler('LRP-FUEL-gasopay2', function(price)
	local src = source
		local xPlayer = ESX.GetPlayerFromId(src)
		local amount = ESX.Math.Round(price)
		local money = xPlayer.getMoney()
		if money >= price then

			xPlayer.removeMoney(amount)
			xPlayer.addInventoryItem("WEAPON_PETROLCAN", 1)
		else
-- you script notification here
	--[[		TriggerClientEvent("LRP-Notificaciones:client",source,
			{
			text = "Necesitas mas dinero.", 
			type = "success", 
			timeout = 2000, 
			layout = "centerRight", 
			queue = "right"
			})
	
			end]]
end)




PLUGIN.name = "Weight"
PLUGIN.author = "Vex"
PLUGIN.description = "Allows for weight to be added to items."

ix.weight = ix.weight or {}

ix.config.Add("maxWeight", 30, "The maximum weight in Kilograms someone can carry in their inventory.", nil, {
	data = {min = 1, max = 100},
	category = "Weight"
})

ix.config.Add("maxOverWeight", 20, "The maximum amount of weight in Kilograms they can go over their weight limit, this should be less than maxWeight to prevent issues.", nil, {
	data = {min = 1, max = 100},
	category = "Weight"
})

ix.util.Include("sh_meta.lua")
ix.util.Include("sv_plugin.lua")

function ix.weight.WeightString(weight, imperial)
	if (imperial) then
		if (weight < 0.453592) then -- Filthy imperial system; Why do I allow their backwards thinking?
			return math.Round(weight * 35.274, 2).." oz"
		else
			return math.Round(weight * 2.20462, 2).." lbs"
		end
	else
		if (weight < 1) then -- The superior units of measurement.
			return math.Round(weight * 1000, 2).." g"
		else
			return math.Round(weight, 2).." kg"
		end
	end
end

function ix.weight.BaseWeight(character)
	local base = ix.config.Get("maxWeight", 30)

	if (character) then
		-- Added strength bonus (2kg per point)
		-- Check for both "strength" and "str"
		local str = character:GetAttribute("strength", 0)
		if (str == 0) then
			str = character:GetAttribute("str", 0)
		end
		base = base + (str * 2)
	end

	return base
end

function ix.weight.CanCarry(weight, carry, character) -- Calculate if you are able to carry something.
	local max = ix.weight.BaseWeight(character) + ix.config.Get("maxOverWeight", 20)

	return (weight + carry) <= max
end

function PLUGIN:SetupMove(client, mv, cmd)
	local character = client:GetCharacter()

	if (character) then
		if SERVER then
			-- Ensure SpeedModifiers table exists
			if not client.SpeedModifiers then
				return -- Exit early if runspeed plugin hasn't initialized yet
			end

			local weight = character:GetData("carry", 0)
			local maxWeight = ix.weight.BaseWeight(character)

			if (weight > maxWeight) then
				local excess = weight - maxWeight
				local endurance = character:GetAttribute("endurance", 0)
				if (endurance == 0) then
					endurance = character:GetAttribute("end", 0)
				end
				
				-- 5% slowdown per kg, reduced by endurance
				local reduction = (excess * 0.05) / (1 + (endurance * 0.1))
				local speedScale = math.Clamp(1 - reduction, 0.1, 1)

				-- Apply modifier using the runspeed manager (REMOVE the true parameter!)
				client:UpdateRunSpeedModifier("weightOverload", ix.plugin.list.runspeed.ModifierTypes.MULT, speedScale)
				client:UpdateWalkSpeedModifier("weightOverload", ix.plugin.list.runspeed.ModifierTypes.MULT, speedScale)
			else
				-- Remove modifiers when no longer overweight
				if client.SpeedModifiers and client.SpeedModifiers.run["weightOverload"] then
					client:RemoveRunSpeedModifier("weightOverload")
				end
				if client.SpeedModifiers and client.SpeedModifiers.walk["weightOverload"] then
					client:RemoveWalkSpeedModifier("weightOverload")
				end
			end
		end
	end
end


if (CLIENT) then
	ix.option.Add("imperial", ix.type.bool, false, {
		category = "Weight"
	})

	function PLUGIN:PopulateItemTooltip(tooltip, item)
		local weight = item:GetWeight()

		if (weight) then
			local row = tooltip:AddRowAfter("description", "weight")
				row:SetText(ix.weight.WeightString(weight, ix.option.Get("imperial", false)))
				row:SetExpensiveShadow(1, color_black)
				row:SizeToContents()
		end
	end
end

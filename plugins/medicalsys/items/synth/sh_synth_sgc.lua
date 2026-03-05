--- Synth-Grade Compound (SGC)
-- Raw biochemical feedstock used as the production currency for batch fabrication.
-- Players collect these and absorb them into their synthesis balance.
-- @item synth_sgc

ITEM.name        = "Synth-Grade Compound"
ITEM.description = "A sealed unit of raw biochemical feedstock. Absorb into your synthesis balance to use for batch fabrication."
ITEM.model       = "models/props_lab/box01a.mdl"
ITEM.category    = "Medical Compounds"
ITEM.width       = 1
ITEM.height      = 1
ITEM.weight      = 0.2

ITEM.functions.Absorb = {
    name = "Absorb to Balance",
    tip  = "Add this SGC unit to your synthesis balance for compound fabrication.",
    icon = "icon16/add.png",
    OnRun = function(item)
        local client = item.player
        local char   = client:GetCharacter()

        if (!char) then
            client:Notify("No active character.")
            return false
        end

        local current = char:GetData("bactaSGC", 0)
        char:SetData("bactaSGC", current + 1)

        -- Sync balance to client
        net.Start("ixBactaSyncBalance")
            net.WriteUInt(current + 1, 16)
        net.Send(client)

        client:Notify("SGC absorbed. Balance: " .. (current + 1))

        return true -- consume item
    end,
}

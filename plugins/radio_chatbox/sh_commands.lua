
local PLUGIN = PLUGIN

ix.command.Add("Comms", {
	description = "Send a global radio message.",
	arguments = {
		ix.type.string
	},
	OnRun = function(self, client, text)
		local options = {
			channel = "global"
		}
		PLUGIN:SendRadioMessage(client, text, nil, options)
	end
})

ix.command.Add("RadioTest", {
	description = "Send a test radio message with optional scrambling.",
	arguments = {
		ix.type.string,
		ix.type.number
	},
	OnRun = function(self, client, text, intensity)
		local options = {
			scrambled = true,
			intensity = intensity or 0.5
		}
		PLUGIN:SendRadioMessage(client, text, {client}, options)
	end
})

<img src="https://cdn.kat.digital/Branding/Version1/Logo_Main.png" alt="Kat Digital" height="50" />
<b>Roblox Binary Reader</b> <br />
<sup>Copyright (C) 2020 Kat Digital Limited. All rights reserved.</sup>

## Roblox Binary Reader
A module to read Roblox model files and convert them to instances. Does not work on unions and non-scriptable properties.

## Example
The module returns a single function. This function takes the raw RBXM binary data and returns a Model instance containing all instances contained within that model.

For a code example, see:
```lua
--Get required Roblox services
local HttpService = game:GetService("HttpService")
local RBXM        = require(script.RBXMReader)

--Perform HTTP request
local httpOkay, data = pcall(HttpService.GetAsync, HttpService, "https://cdn.kat.gg/Testing/Tree.rbxm")

--Read instance or print error
if (httpOkay) then
	local instance = RBXM.readRBXM(data)
	instance.Parent = workspace
	print("Read successful")
else
	print("HTTP Failed")
end
```

## Releases
You can find all releases of this project here: <br />
https://github.com/Kat-Digital/RBXM-Reader/releases

## Documentation
Technical documentation and information about the Kat Digital Roblox model file decoder project. <br />
https://docs.kat.gg/Projects/Roblox-Model-File-Decoder

## License
This project is licensed under the GPLv3 license, meaning you can use it in your own projects but must open-source anything you distribute that uses this code under the same license, and state any changes you've made to it. We encourage you to learn from our work but do not want it to be distributed as part of proprietary or commercial products.

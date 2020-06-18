--[[
	@Author: Anna W. Anna W. <https://devforum.roblox.com/u/ImActuallyAnna> Skylar L. <https://devforum.roblox.com/u/ScobayDu>
	@Description: RBXM File Reader
	@Date of Creation: 09. 05. 2020

	Copyright (C) 2020 Kat Digital Limited.
	 
	This program is free software: you can redistribute it and/or modify  
	it under the terms of the GNU General Public License as published by  
	the Free Software Foundation, version 3.
	
	This program is distributed in the hope that it will be useful, but 
	WITHOUT ANY WARRANTY; without even the implied warranty of 
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
	General Public License for more details.
	
	You should have received a copy of the GNU General Public License 
	along with this program. If not, see <http://www.gnu.org/licenses/>
--]]

--Binary format specification can be found at:
--http://www.classy-studios.com/Downloads/RobloxFileSpec.pdf

--Dependencies
local BASE_FOLDER   = script
local Binary        = require(BASE_FOLDER.Binary)
local Stream        = require(BASE_FOLDER.Stream)
local LZ4           = require(BASE_FOLDER.LZ4)

--Shorten/Efficiency-related declarations
local byte = string.byte
local char = string.char
local insert = table.insert

--Helper function to compare two byte arrays
function compareByteArrays(array0, array1)
	--Disqualify any cases where array  lengths are not the same
	if (#array0 ~= #array1) then return false end
	
	--Compare byte arrays as strings
	local str0 = char(unpack(array0, 1, #array0))
	local str1 = char(unpack(array1, 1, #array1))
	return str0 == str1
end

--Helper function to read a string from the stream
function readString(data)
	--Read length of the string, and then the string
	local length = Binary.decodeInt(data:read(4), true)
	if (length == 0) then return "" end
	return data:read(length)
end

--Helper function to attempt to set a property on an instance
function setPropertyDirect(instance, name, value)
	instance[name] = value
end

local PROPERTY_NAME_FIX = {
	["size"]        = "Size";
	["Color3uint8"] = "Color";
}

function setProperty(instance, name, value)
	--Some values are serialized under a different name than the property - we can look these up in the table
	local name = PROPERTY_NAME_FIX[name] or name
	
	--Attempt to set the property
	local ok, errorStr = pcall(setPropertyDirect, instance, name, value)
	if (not ok) then
		--warn("Failed to set property " .. name .. " on " .. instance.ClassName .. " to " .. tostring(value) .. ": " .. errorStr)
		
		if (instance:IsA("BaseScript") and name == "Source") then
			print("Source: ")
			print(value)
		end
	end
end

--Helper function to read interleaved integers
function readInterleaved(stream, valueLength, valueCount)
	--Pre-allocate large table; fill with 0's as placeholders; passing a table to this will cause the
	--array to be filled with the same table pointer, resulting in a bug where all returned values are
	--the same
	local values = table.create(valueCount, 0)
	
	--Fill with new tables with the correct length
	for i = 1, valueCount do
		values[i] = table.create(valueLength, 0)
	end
	
	for i = 1, valueLength do
		--Read byte for each value
		for j = 1, valueCount do
			values[j][i] = stream:read(1)
		end
	end
	
	--Concatenate all the values
	for i = 1, valueCount do
		values[i] = table.concat(values[i])
	end
	
	return values
end

--Helper function to read a Roblox integer
--This undoes the transformation integers undergo before being stored to a file
function readRobloxInt(strInput, littleEndian)
	local int = Binary.decodeInt(strInput, littleEndian)
	
	if (int % 2 == 0) then
		return int / 2
	else
		return -(int+1)/2
	end
end

--Helper function to read a Roblox Float
--The sign is the LSB instead of the MSB - the rest of the float is left-shifted by 1 bit
function readRobloxFloat(strInput)
	--Convert Roblox float to IEEE754 float
	local int = Binary.decodeInt(strInput, false)
	local sign = int % 2
	local str = Binary.encodeInt(sign*0x80000000 + (int-sign)/2, 4)
	
	--Decode string to float
	return Binary.decodeFloat(str, false)
end

--NormalID list
local NORMAL_IDS = {
	[0x01] = Enum.NormalId.Front;
	[0x02] = Enum.NormalId.Bottom;
	[0x04] = Enum.NormalId.Left;
	[0x08] = Enum.NormalId.Back;
	[0x10] = Enum.NormalId.Top;
	[0x20] = Enum.NormalId.Right;
}

--Axis list
local AXIS_VALUES = {
	[0x00] = Vector3.new( 0, 0, 0);
	[0x01] = Vector3.new( 0, 0, 1);
	[0x02] = Vector3.new( 0, 1, 0);
	[0x03] = Vector3.new( 0, 1, 1);
	[0x04] = Vector3.new( 1, 0, 0);
	[0x05] = Vector3.new( 1, 0, 1);
	[0x06] = Vector3.new( 1, 1, 0);
	[0x07] = Vector3.new( 1, 1, 1);
}

--CFrame special angles
local CF000 = 0
local CF090 = math.pi/2
local CF180 = math.pi
local CF270 = -math.pi/2
local CFRAME_SPECIAL_ANGLES = {
	[0x02] = CFrame.Angles(CF000, CF000, CF000);
	[0x03] = CFrame.Angles(CF090, CF000, CF000);
	[0x05] = CFrame.Angles(CF180, CF000, CF000);
	[0x06] = CFrame.Angles(CF270, CF000, CF000);
	[0x07] = CFrame.Angles(CF180, CF000, CF270);
	[0x09] = CFrame.Angles(CF090, CF090, CF000);
	[0x0A] = CFrame.Angles(CF000, CF000, CF090);
	[0x0C] = CFrame.Angles(CF270, CF270, CF000);
	
	[0x0D] = CFrame.Angles(CF270, CF000, CF270);
	[0x0E] = CFrame.Angles(CF000, CF270, CF000);
	[0x10] = CFrame.Angles(CF090, CF000, CF090);
	[0x11] = CFrame.Angles(CF180, CF090, CF000);
	[0x14] = CFrame.Angles(CF180, CF000, CF180);
	[0x15] = CFrame.Angles(CF270, CF000, CF180);
	[0x17] = CFrame.Angles(CF000, CF000, CF180);
	[0x18] = CFrame.Angles(CF090, CF000, CF180);
	
	[0x19] = CFrame.Angles(CF000, CF000, CF270);
	[0x1B] = CFrame.Angles(CF090, CF270, CF000);
	[0x1C] = CFrame.Angles(CF180, CF000, CF090);
	[0x1E] = CFrame.Angles(CF270, CF090, CF000);
	[0x1F] = CFrame.Angles(CF090, CF000, CF270);
	[0x20] = CFrame.Angles(CF000, CF090, CF000);
	[0x22] = CFrame.Angles(CF270, CF000, CF090);
	[0x23] = CFrame.Angles(CF180, CF270, CF000);
}

--Functions to read properties to instances
local PROPERTY_FUNCTIONS
PROPERTY_FUNCTIONS = {
	--0x00 is invalid

	--String
	[0x01] = function(nInstances, stream)
		local values = table.create(nInstances, "")
		for i = 1, nInstances do 
			values[i] = readString(stream)
		end
		
		return values
	end;
	
	--Boolean
	[0x02] = function(nInstances, stream)
		local values = table.create(nInstances, false)
		for i = 1, nInstances do 
			values[i] = stream:read(1) ~= "\0"
		end
		
		return values
	end;
	
	--Int32
	[0x03] = function(nInstances, stream)
		local valuesRaw = readInterleaved(stream, 4, nInstances)
		local values = table.create(nInstances, 0)
		
		for i = 1, nInstances do
			values[i] = readRobloxInt(valuesRaw[i])
		end
		
		return values
	end;
	
	--Float
	[0x04] = function(nInstances, stream)
		local valuesRaw = readInterleaved(stream, 4, nInstances)
		local values = table.create(nInstances, 0)
		
		for i = 1, nInstances do
			values[i] = readRobloxFloat(valuesRaw[i])
		end
		
		return values
	end;
	
	--Double
	[0x05] = function(nInstances, stream)
		local valuesRaw = readInterleaved(stream, 8, nInstances)
		local values = table.create(nInstances, 0)
		
		for i = 1, nInstances do
			values[i] = Binary.decodeDouble(valuesRaw[i]:reverse())
		end
		
		return values
	end;
	
	--UDim
	[0x06] = function(nInstances, stream)
		local floatsRaw = readInterleaved(stream, 4, nInstances)
		local int32sRaw = readInterleaved(stream, 4, nInstances)
		local values = table.create(nInstances, 0)
		
		for i = 1, nInstances do
			values[i] = UDim.new(
				readRobloxFloat(floatsRaw[i]),
				readRobloxInt  (int32sRaw[i])
			)
		end
		
		return values
	end;
	
	--UDim2
	[0x07] = function(nInstances, stream)
		local scalesX  = readInterleaved(stream, 4, nInstances)
		local scalesY  = readInterleaved(stream, 4, nInstances)
		local offsetsX = readInterleaved(stream, 4, nInstances)
		local offsetsY = readInterleaved(stream, 4, nInstances)
		local values = table.create(nInstances, 0)
		
		for i = 1, nInstances do
			values[i] = UDim2.new(
				readRobloxFloat(scalesX[i]),
				readRobloxInt  (offsetsX[i]),
				readRobloxFloat(scalesY[i]),
				readRobloxInt  (offsetsY[i])
			)
		end
		
		return values
	end;
	
	--Ray
	[0x08] = function(nInstances, stream)
		local values = table.create(nInstances, 0)
		
		for i = 1, nInstances do
			local originX = Binary.decodeFloat(stream:read(4):reverse())
			local originY = Binary.decodeFloat(stream:read(4):reverse())
			local originZ = Binary.decodeFloat(stream:read(4):reverse())
			local dirX    = Binary.decodeFloat(stream:read(4):reverse())
			local dirY    = Binary.decodeFloat(stream:read(4):reverse())
			local dirZ    = Binary.decodeFloat(stream:read(4):reverse())
			
			values[i] = Ray.new(
				Vector3.new(originX, originY, originZ), 
				Vector3.new(dirX, dirY, dirZ)
			)
		end
		
		return values
	end;
	
	--Faces
	[0x09] = function(nInstances, stream)
		local values = table.create(nInstances, 0)
		
		for i = 1, nInstances do
			local index = Binary.decodeInt(stream:read(1))
			local surface = NORMAL_IDS[index]
			values[i] = surface
			
			assert(surface ~= nil, "RBXMReader E007: Unknown surface type: " .. index)
		end
		
		return values
	end;
	
	--Axis
	[0x0A] = function(nInstances, stream)
		local values = table.create(nInstances, 0)
		
		for i = 1, nInstances do
			local index = Binary.decodeInt(stream:read(1))
			local axis = AXIS_VALUES[index]
			values[i] = axis
			
			assert(axis ~= nil, "RBXMReader E008: Unknown axis type: " .. index)
		end
		
		return values
	end;
	
	--BrickColor
	[0x0B] = function(nInstances, stream)
		local valuesRaw = readInterleaved(stream, 4, nInstances)
		local values = table.create(nInstances, 0)
		
		for i = 1, nInstances do
			values[i] = BrickColor.new(Binary.decodeInt(stream:read(4)))
		end
		
		return values
	end;
	
	--Color3
	[0x0C] = function(nInstances, stream)
		local valuesRawR = readInterleaved(stream, 4, nInstances)
		local valuesRawG = readInterleaved(stream, 4, nInstances)
		local valuesRawB = readInterleaved(stream, 4, nInstances)
		local values = table.create(nInstances, 0)
		
		for i = 1, nInstances do
			values[i] = Color3.new(
				readRobloxFloat(valuesRawR[i]),
				readRobloxFloat(valuesRawG[i]),
				readRobloxFloat(valuesRawB[i])
			)
		end
		
		return values
	end;
	
	--Vector2
	[0x0D] = function(nInstances, stream)
		local valuesRawX = readInterleaved(stream, 4, nInstances)
		local valuesRawY = readInterleaved(stream, 4, nInstances)
		local values = table.create(nInstances, 0)
		
		for i = 1, nInstances do
			values[i] = Vector2.new(
				readRobloxFloat(valuesRawX[i]),
				readRobloxFloat(valuesRawY[i])
			)
		end
		
		return values
	end;
	
	--Vector3
	[0x0E] = function(nInstances, stream)
		local valuesRawX = readInterleaved(stream, 4, nInstances)
		local valuesRawY = readInterleaved(stream, 4, nInstances)
		local valuesRawZ = readInterleaved(stream, 4, nInstances)
		local values = table.create(nInstances, 0)
		
		for i = 1, nInstances do
			values[i] = Vector3.new(
				readRobloxFloat(valuesRawX[i]),
				readRobloxFloat(valuesRawY[i]),
				readRobloxFloat(valuesRawZ[i])
			)
		end
		
		return values
	end;
	
	--0x0F is invalid
	
	--CFrame
	[0x10] = function(nInstances, stream)
		local cframeAngles = table.create(nInstances, CFrame.new())
		local values = table.create(nInstances, CFrame.new())
		
		--Get CFrame angles
		for i = 1, nInstances do
			--Check CFrame type
			local byteValue = Binary.decodeInt(stream:read(1))
			local specialAngle = CFRAME_SPECIAL_ANGLES[byteValue]
			
			--If we have a special value, store it. Otherwise, read 9 untransformed floats to get
			--the rotation matrix
			if (specialAngle == nil) then
				local matrixValues = table.create(9, 0)
				for j = 1, 9 do
					matrixValues[j] = Binary.decodeFloat(stream:read(4), true)
				end
				
				cframeAngles[i] = CFrame.new(0, 0, 0, unpack(matrixValues, 1, 9))
			else
				cframeAngles[i] = specialAngle
			end
		end
		
		--Read position data - invoke function for Vector3s
		local positions = PROPERTY_FUNCTIONS[0x0E](nInstances, stream)
		
		--Generate final CFrames
		for i = 1, nInstances do
			values[i] = CFrame.new(positions[i]) * cframeAngles[i]
		end
		
		return values
	end;
	
	--Quaternion; unsure how this is implemented. Might require some experimentation later
	--TODO: Fix this
	[0x11] = function(nInstances, stream)
		warn("RBXMReader W001: Using quaternions")
		return PROPERTY_FUNCTIONS[0x10](nInstances, stream)
	end;
	
	--Enums - Roblox accepts EnumProperty = number so we can just return an array of numbers
	[0x12] = function(nInstances, stream)
		local valuesRaw = readInterleaved(stream, 4, nInstances)
		local values = table.create(nInstances, 0)
		
		for i = 1, nInstances do
			values[i] = Binary.decodeInt(valuesRaw[i])
		end
		
		return values
	end;
	
	--Instance references
	[0x13] = function(nInstances, stream, instances)
		local valuesRaw = readInterleaved(stream, 4, nInstances)
		local values = table.create(nInstances, 0)
		
		local lastValue = 0
		for i = 1, nInstances do
			local rawValue = readRobloxInt(valuesRaw[i])
			local newValue = rawValue + lastValue
			lastValue = newValue
			values[i] = instances[newValue]
		end
		
		return values
	end;
	
	--Color3uint8
	[0x1A] = function(nInstances, stream)
		local valuesR = table.create(nInstances, 0)
		local valuesG = table.create(nInstances, 0)
		local valuesB = table.create(nInstances, 0)
		local values  = table.create(nInstances, 0)
		
		for i = 1, nInstances do valuesR[i] = Binary.decodeInt(stream:read(1)) end
		for i = 1, nInstances do valuesG[i] = Binary.decodeInt(stream:read(1)) end
		for i = 1, nInstances do valuesB[i] = Binary.decodeInt(stream:read(1)) end
		
		for i = 1, nInstances do 
			values[i] = Color3.fromRGB(valuesR[i], valuesG[i], valuesB[i])
		end
		
		return values
	end;
}

--Function to read an RBXM file
function readRBXM(binaryData)
	--Create new stream
	local data = Stream.new(binaryData)
	
	--Read & verify file header
	--First 16 bytes should be 3C 72 6F 62 6C 6F 78 21 89 FF 0D 0A 1A 0A 00 00
	local headerActualBytes = { byte(data:read(16), 1, 16) }
	local headerExpectedBytes = {
			0x3C, 0x72, 0x6F, 0x62, 
			0x6C, 0x6F, 0x78, 0x21, 
			0x89, 0xFF, 0x0D, 0x0A, 
			0x1A, 0x0A, 0x00, 0x00 
		}
	
	assert(
			compareByteArrays(headerActualBytes, headerExpectedBytes),
			"RBXMReader E001: Invalid RBXM header"
		)
	
	--Create a new model to dump instances into
	local rootModel = Instance.new("Model")
	
	--Read number of unique types
	local nUniqueTypes = Binary.decodeInt(data:read(4), true)
	local nObjects     = Binary.decodeInt(data:read(4), true)
	
	--Verify that the next 8 bytes are 0
	assert(Binary.decodeInt(data:read(4)) == 0, "RBXMReader E002: Invalid RBXM header")
	assert(Binary.decodeInt(data:read(4)) == 0, "RBXMReader E002: Invalid RBXM header")
	
	--Create lookup tables for information
	local METADATA      = {}
	local SHAREDSTRINGS = {}
	local TYPES         = {}
	local INSTANCES     = {}
	
	--Read header data
	while true do
		--Read type through look-ahead, once we get a PROP, exit
		local typeStr = data:lookAhead(4)
		if (typeStr == "PROP") then break end
		
		--Read type bytes and compressed data
		local headerType = data:read(4)
		local headerData = Stream.new(LZ4.decode(data))
		
		--Read META, SSTR and INST records
		if (headerType == "META") then
			--Read number of key/value pairs (possibly?); this *should* be 1 at the moment
			local length, j = Binary.decodeInt(headerData:read(4), true), 0
			
			for j = 1, length do
				--Read key/value pairs, and store the result
				local key   = readString(headerData)
				local value = readString(headerData)
				METADATA[key] = value
			end
		elseif (headerType == "SSTR") then
			--Read shared strings
			--TODO: Implement this; low priority currently
		elseif (headerType == "INST") then
			--Read INST thing
			local index      = Binary.decodeInt(headerData:read(4), true)
			local className  = readString(headerData)
			local isService  = headerData:read(1) ~= "\0"
			local nInstances = Binary.decodeInt(headerData:read(4), true)
			local referents  = readInterleaved(headerData, 4, nInstances)
			
			--Reading RBXM, so we should never have a service
			assert(not isService, "RBXMReader E004: File contains services")
			
			--Create the instances
			local instances, j, referent = table.create(nInstances, 0), 1, 0
			for j = 1, nInstances do
				referent = referent + readRobloxInt(referents[j])
				local instance = Instance.new(className)
				instances[j] = instance
				INSTANCES[referent] = instance
			end
			
			--Store the type reference
			TYPES[index] = {
				Index         = index;
				ClassName     = className;
				IsService     = isService;
				InstanceCount = nInstances;
				Instances     = instances;
			}
		else
			--Error because of unexpected header type
			error("RBXMReader E003: Unexpected header object type: " .. headerType)
		end
	end
	
	--Read actual body
	while true do
		--Read object type and decompress its data
		local objType = data:read(4)
		local objData = Stream.new(LZ4.decode(data))
		
		--These seem to all be PROP elements but we'll make this easily expandable for the future
		if (objType == "PROP") then
			--Handle property descriptor
			local classIndex   = Binary.decodeInt(objData:read(4), true)
			local propertyName = readString(objData)
			local propertyType = Binary.decodeInt(objData:read(1))
			local descriptor   = TYPES[classIndex]
			local nInstances   = descriptor.InstanceCount
			local instances    = descriptor.Instances
			
			--Check for property type
			local func = PROPERTY_FUNCTIONS[propertyType]
			--assert(func ~= nil, "RBXMReader E006: Invalid or unknown property type: " .. propertyType)
			
			if (func ~= nil) then
				--Get property values
				local values = func(nInstances, objData, INSTANCES)
				
				--Iterate over instances with this function
				local j
				for j = 1, nInstances do
					setProperty(instances[j], propertyName, values[j])
				end
			else
				--Print any properties we'd want to check here; debugging reasons
			end
		elseif (objType == "PRNT") then
			--Parent data
			--Read length of the list
			--May have to skip one character? We have an extra 0x00
			objData:read(1)
			local parentLength = Binary.decodeInt(objData:read(4), true)
			local referents = readInterleaved(objData, 4, parentLength)
			local parents   = readInterleaved(objData, 4, parentLength)
			
			local cReferent = 0
			local cParent   = 0
			for i = 1, parentLength do
				cReferent = cReferent + readRobloxInt(referents[i])
				cParent   = cParent   + readRobloxInt(parents[i])
				
				local instance = INSTANCES[cReferent]
				if (cParent == -1) then
					instance.Parent = rootModel
				else
					instance.Parent = INSTANCES[cParent]
				end
			end
			
			break
		else
			error("RBXMReader E005: File contains unexpected body element: " .. objType)
		end
	end
	
	--Ending bytes
	local endExpectedBytes = { 
		0x45, 0x4E, 0x44, 0x00, 
		0x00, 0x00, 0x00, 0x00, 
		0x09, 0x00, 0x00, 0x00, 
		0x00, 0x00, 0x00, 0x00, 
		0x3C, 0x2F, 0x72, 0x6F, 
		0x62, 0x6C, 0x6F, 0x78, 
		0x3E 
	}
	
	local footerBytes = { byte(data:read(25), 1, 25) }
	
	assert(
			compareByteArrays(footerBytes, endExpectedBytes),
			"RBXMReader E006: Invalid RBXM footer"
		)
	
	--Return root object
	return rootModel
end

return {
	readRBXM = readRBXM;
}

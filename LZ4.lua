--[[
	@Author: Anna W. <https://devforum.roblox.com/u/ImActuallyAnna> Skylar L. <https://devforum.roblox.com/u/ScobayDu>
	@Description: Module to read LZ4-compressed data
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

--Dependencies
local BASE_FOLDER   = script.Parent
local Binary        = require(BASE_FOLDER.Binary)
local Stream        = require(BASE_FOLDER.Stream)

--LZ4 library
local LZ4 = {}

--Function to decode LZ4 data
function LZ4.decode(streamOrString)
	--Make sure we have a data stream
	local data
	if (type(streamOrString) == "string") then
		data = Stream.new(streamOrString)
	else
		data = streamOrString
	end
	
	--Read LZ4 header
	local compressedLength   = Binary.decodeInt(data:read(4), true)
	local uncompressedLength = Binary.decodeInt(data:read(4), true)
	assert(Binary.decodeInt(data:read(4), true) == 0, "LZ4 E001: Invalid LZ4 header")
	
	--Create byte array for uncompressed data, and a helper function to add data to it
	local uncompressedData = table.create(uncompressedLength, -1)
	local uncompressedPosition = 0
	
	local function addUncompressed(str)
		local i, len = 1, #str
		for i = 1, len do
			assert(uncompressedPosition + i <= uncompressedLength, "LZ4 E004: Too much uncompressed data")
			uncompressedData[uncompressedPosition + i] = string.byte(str, i)
		end
		
		uncompressedPosition = uncompressedPosition + len
	end
	
	--Helper function to read 'matchLength' bytes fromt he end of the stream
	local function readMatchData(offset, matchLength)
		--Get raw string - we may have to repeat this several times
		local startPos = (uncompressedPosition - offset) + 1
		local endPos = uncompressedPosition + matchLength + 1
		
		--Append match data
		local pos = startPos
		local idx = uncompressedPosition + 1
		
		while (idx < endPos) do
			uncompressedData[idx] = uncompressedData[pos]
			idx = idx + 1
			pos = pos + 1
		end
		
		uncompressedPosition = idx - 1
	end
	
	--Generate stream from compressed data
	local data = Stream.new(data:read(compressedLength))
	
	--Repeat until we have no data left
	while true do
		--Read token byte
		local token = Binary.decodeInt(data:read(1))
		local literalLength = math.floor(token/16)
		local matchLength   = token % 16
		
		--If literal length is 15, we read additional bytes to add to the length
		--The length ends at the first byte that is not equal to 255
		if (literalLength == 15) then
			local nextByte 
			repeat
				nextByte = Binary.decodeInt(data:read(1))
				literalLength = literalLength + nextByte
			until nextByte ~= 255
		end
		
		--Read literal data
		if (literalLength > 0) then
			addUncompressed(data:read(literalLength))
		end
		
		--Read offset value, or exit if we have no match data
		if (data:hasData()) then
			local offset = Binary.decodeInt(data:read(2), true)
			
			--0 is an invalid offset
			assert(offset ~= 0, "LZ4 E006: Offset can not be 0")
			
			--If match length is 15, we read additional bytes to add to the length
			--The length ends at the first byte that is not equal to 255
			if (matchLength == 15) then
				local nextByte 
				repeat
					nextByte = Binary.decodeInt(data:read(1))
					matchLength = matchLength + nextByte
				until nextByte ~= 255
			end
			
			--Match data length is actually 4 more than is stored; 4 is the minimum length
			matchLength = matchLength + 4
			
			--Read data to append
			readMatchData(offset, matchLength)
		else
			--Exit the loop; no match data exists
			break
		end
	end
	
	--Check that the decompressed data is the correct length
	assert(uncompressedPosition == uncompressedLength, "LZ4 E005: Uncompressed length is incorrect; expected " .. uncompressedLength .. ", got " .. uncompressedPosition)
	
	--Return decompressed data
	--We have to take a slightly slower and uglier approach here because large compressed 
	--blocks (>254 values) may result in a "too many values to unpack" error
	--
	--Original code:
	--return string.char(unpack(uncompressedData, 1, uncompressedLength))
	
	local output = {}
	for i = 1, uncompressedLength, 256 do
		local append = string.char(unpack(uncompressedData, i, math.min(i + 255, uncompressedLength)))
		table.insert(output, append)
	end
	
	return table.concat(output)
end

--Return module
return LZ4

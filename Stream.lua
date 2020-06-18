--[[
	@Author: Anna W. <https://devforum.roblox.com/u/ImActuallyAnna>
	@Description: Utility to create stream-like behavior from a string of data
	@Date of Creation: 19. 04. 2020
	
	Copyright (C) 2020 Kat Digital Limited.
	 
	This program is free software: you can redistribute it and/or modify  
	it under the terms of the GNU General Public License as published by  
	the Free Software Foundation, version 3.
	
	This program is distributed in the hope that it will be useful, but 
	WITHOUT ANY WARRANTY; without even the implied warranty of 
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
	General Public License for more details.
	
	You should have received a copy of the GNU General Public License 
	along with this program. If not, see <http://www.gnu.org/licenses/>.	
--]]

--Stream class setup
local Stream = {}
Stream.__index = Stream

--Constructor
function Stream.new(data)
	return setmetatable({
		Data = data;
		Position = 1;
	}, Stream)
end

--Method to read a given number of bytes
function Stream:read(nBytes)
	--Return nil if we've reached the end of the stream
	if (self.Position > #self.Data) then return nil end

	--If nBytes is nil, return a single byte
	if (nBytes == nil) then nBytes = 1 end
	
	--If nBytes is math.huge, return the remaining data
	if (nBytes == math.huge) then
		local oldPos = self.Position
		self.Position = math.huge
		return self.Data:sub(oldPos)
	end
	
	--Return data and increment position
	local out = self.Data:sub(self.Position, self.Position+(nBytes-1))
	self.Position = self.Position + nBytes
	return out
end

--Method to read a number of bytes without advancing the position
function Stream:lookAhead(nBytes)
	--Return nil if we've reached the end of the stream
	if (self.Position > #self.Data) then return nil end
	
	--Return data and increment position
	local out = self.Data:sub(self.Position, self.Position+(nBytes-1))
	return out
end

--Method to read an unknown number of bytes until a pattern occurs
--If the pattern isn't matched, read until the end of the string
function Stream:readUntil(pattern)
	--Return nil if we've reached the end of the stream
	if (self.Position > #self.Data) then return nil end
	
	--Try to find the pattern
	local remaining = self.Data:sub(self.Position)
	local s, f = remaining:find(pattern)
	
	--Return the remaining data and nil if the string wasn't found
	if (s == nil) then
		local pos = self.Position
		self.Position = #self.Data + 1
		return self.Data:sub(pos), nil
	end
	
	--Otherwise, return data before the begging of the pattern, and the matched pattern
	--Position after this is the first character following the matched patterns
	local pos = self.Position
	self.Position = self.Position + f
	
	return self.Data:sub(pos, pos+(s-2)), self.Data:sub(pos+(s-1), pos+(f-1))
end

--Method to read a pattern match, and return the matched data
function Stream:readMatch(str)
	local str = self:lookAhead(#str):match("^(" .. str .. ")")
	self.Position = self.Position + #str
	return str
end

--Method to skip a given number of bytes
function Stream:skip(nBytes)
	self.Position = self.Position + nBytes
end

--Method to jump back a number of bytes
function Stream:jumpBack(nBytes)
	self.Position = math.max(self.Position - nBytes, 1)
end

--Check if the next set of characters match a string; this returns a boolean and does not
--affect the string position
function Stream:checkNext(str)
	return self:lookAhead(#str):match("^(" .. str .. ")")
end

--Method to check if we have data
function Stream:hasData()
	return self.Position <= #self.Data
end

--Output API
return Stream

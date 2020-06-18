--[[
	@Author: Anna W. <https://devforum.roblox.com/u/ImActuallyAnna> Skylar L. <https://devforum.roblox.com/u/ScobayDu>
	@Description: Pure-Lua binary operations for 5.1
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
	along with this program. If not, see <http://www.gnu.org/licenses/>
--]]

--Module to handle binary encoding and decoding
local Binary = {}

--Efficiency is key; we might be handling huge amounts of information
local append 	= table.insert
local char 		= string.char
local byte 		= string.byte
local substr 	= string.sub
local floor 	= math.floor
local ceil		= math.ceil
local abs		= math.abs
local pow 		= math.pow
local log 		= math.log

--Binary logic
function Binary.bitwiseOr(a, b)
	return bit32.bor(a, b)
	
	--[[local out = 0
	for i = 1, 32 do
		if (a%2 == 1 or b%2 == 1) then out = out + 4294967296 end 
		a = floor(a/2)
		b = floor(b/2)
		out = out / 2
	end
	return out]]
end

function Binary.bitwiseAnd(a, b)
	return bit32.band(a, b)
	
	--[[local out = 0
	for i = 1, 32 do
		if (a%2 == 1 and b%2 == 1) then out = out + 4294967296 end 
		a = floor(a/2)
		b = floor(b/2)
		out = out / 2
	end
	return out]]
end

function Binary.bitwiseXor(a, b)
	return bit32.bxor(a, b)
	
	--[[local out = 0
	for i = 1, 32 do
		if (a%2 ~= b%2) then out = out + 4294967296 end 
		a = floor(a/2)
		b = floor(b/2)
		out = out / 2
	end
	return out]]
end

function Binary.bitwiseNot(a)
	--We don't use bit32.bnot() here because the equivalent 
	--arithmetic operation actually faster
	return 4294967295 - a
end

function Binary.byteNot(a)
	--We don't use bit32.bnot()%256 here because the equivalent 
	--arithmetic operation actually faster
	return 255 - a
end

--Shifting
function Binary.leftShift(a, n)
	return math.floor(a * math.pow(2, n)) % 4294967296
end

function Binary.rightShift(a, n)
	return math.floor(a / math.pow(2, n)) % 4294967296
end

--Integers
function Binary.encodeInt(number, nBytes)
	--Make sure we're dealing with an integer
	number = floor(number) % pow(256, nBytes)
	
	--Iterate over bytes and generate the output
	local bytesOut = {}
	for i = 0, nBytes-1 do
		bytesOut[nBytes - i] = char(number % 256)
		number = floor(number/256)
	end
	
	--Concatenate and return
	return table.concat(bytesOut)
end

function Binary.decodeInt(str, useLittleEndian)
	--Reverse the string if we're using little endian
	if (useLittleEndian) then str = str:reverse() end
	
	--Decode
	local out = byte(str, 1)
	for i = 2, #str do
		out = out*256 + byte(str, i)
	end
	
	return out
end

function Binary.decodeSignedInt(str, useLittleEndian)
	--Get basic string first
	local unsigned = Binary.decodeInt(str, useLittleEndian)
	local max_value = math.pow(256, #str)
	
	--If the sign (first bit) is 0, just return the number
	if (unsigned < max_value/2) then return unsigned end
	
	--Otherwise, get the bitwise NOT of the value and negate
	return -(max_value - unsigned)
end

--Doubles
--Define some commonly used variables here so we don't have to do this at runtime
local log2 = log(2)
local pow2to52 = pow(2,52)
local pow2to23 = pow(2,23)
local f08 = pow(2, 8)
local f16 = pow(2,16)
local f24 = pow(2,24)
local f32 = pow(2,32)
local f40 = pow(2,40)
local f48 = pow(2,48)

function Binary.encodeDouble(number)
	--IEEE double-precision floating point number
	--Specification: https://en.wikipedia.org/wiki/Double-precision_floating-point_format
	
	--Separate out the sign, exponent and fraction
	local sign 		= number < 0 and 1 or 0
	local exponent 	= ceil(log(abs(number))/log2) - 1
	local fraction	= abs(number)/pow(2,exponent) - 1
	
	--Make sure the exponent stays in range - allowed values are -1023 through 1024
	if (exponent < -1023) then 
		--We allow this case for subnormal numbers and just clamp the exponent and re-calculate the fraction
		--without the offset of 1
		exponent = -1023
		fraction = abs(number)/pow(2,exponent)
	elseif (exponent > 1024) then
		--If the exponent ever goes above this value, something went horribly wrong and we should probably stop
		error("Exponent out of range: " .. exponent)
	end
	
	--Handle special cases
	if (number == 0) then
		--Zero
		exponent = -1023
		fraction = 0
	elseif (abs(number) == math.huge) then
		--Infinity
		exponent = 1024
		fraction = 0
	elseif (number ~= number) then
		--NaN
		exponent = 1024
		fraction = (pow2to52-1)/pow2to52
	end
	
	--Prepare the values for encoding
	local expOut = exponent + 1023                              --The exponent is an 11 bit offset-binary
	local fractionOut = fraction * pow2to52                     --The fraction is 52 bit, so multiplying it by 2^52 will give us an integer
	
	
	--Combine the values into 8 bytes and return the result
	return char(
			128*sign + floor(expOut/16),                        --Byte 0: Sign and then shift exponent down by 4 bit
			(expOut%16)*16 + floor(fractionOut/f48),            --Byte 1: Shift fraction up by 4 to give most significant bits, and fraction down by 48
			floor(fractionOut/f40)%256,                         --Byte 2: Shift fraction down 40 bit
			floor(fractionOut/f32)%256,                         --Byte 3: Shift fraction down 32 bit
			floor(fractionOut/f24)%256,                         --Byte 4: Shift fraction down 24 bit
			floor(fractionOut/f16)%256,                         --Byte 5: Shift fraction down 16 bit
			floor(fractionOut/f08)%256,                         --Byte 6: Shift fraction down 8 bit
			floor(fractionOut % 256)                            --Byte 7: Last 8 bits of the fraction
		)
end

function Binary.decodeDouble(str, useLittleEndian)
	--Reverse the string if we're using little endian
	if (useLittleEndian) then str = str:reverse() end
	
	--Get bytes from the string
	local byte0 = byte(substr(str,1,1))
	local byte1 = byte(substr(str,2,2))
	local byte2 = byte(substr(str,3,3))
	local byte3 = byte(substr(str,4,4))
	local byte4 = byte(substr(str,5,5))
	local byte5 = byte(substr(str,6,6))
	local byte6 = byte(substr(str,7,7))
	local byte7 = byte(substr(str,8,8))
	
	--Separate out the values
	local sign = byte0 >= 128 and 1 or 0
	local exponent = (byte0%128)*16 + floor(byte1/16)
	local fraction = (byte1%16)*f48 
	                 + byte2*f40 + byte3*f32 + byte4*f24 
	                 + byte5*f16 + byte6*f08 + byte7
	
	--Handle special cases
	if (exponent == 2047) then
		if (fraction == 0) then return pow(-1,sign) * math.huge end
		if (fraction == pow2to52-1) then return 0/0 end
	end
	
	--Combine the values and return the result
	if (exponent == 0) then
		--Handle subnormal numbers
		return pow(-1,sign) * pow(2,exponent-1023) * (fraction/pow2to52)
	else
		--Handle normal numbers
		return pow(-1,sign) * pow(2,exponent-1023) * (fraction/pow2to52 + 1)
	end
end

--Format specification at:
--https://en.wikipedia.org/wiki/Single-precision_floating-point_format
function Binary.decodeFloat(str, useLittleEndian)
	--Reverse the string if we're using little endian
	if (useLittleEndian) then str = str:reverse() end
	
	--Get bytes from the string
	local byte0 = byte(substr(str,1,1))
	local byte1 = byte(substr(str,2,2))
	local byte2 = byte(substr(str,3,3))
	local byte3 = byte(substr(str,4,4))
	
	--Separate out the values
	local sign = byte0 >= 128 and 1 or 0
	local exponent = (byte0%128)*2 + floor(byte1/128)
	local fraction = (byte1%128)*f16 + byte2*f08 + byte3
	
	--Handle special cases
	if (exponent == 255) then
		if (fraction == 0) then return pow(-1,sign) * math.huge end
		if (fraction == pow2to23-1) then return 0/0 end
	end
	
	--Combine the values and return the result
	if (exponent == 0) then
		--Handle subnormal numbers
		return pow(-1,sign) * pow(2,exponent-127) * (fraction/pow2to23)
	else
		--Handle normal numbers
		return pow(-1,sign) * pow(2,exponent-127) * (fraction/pow2to23 + 1)
	end
end

return Binary

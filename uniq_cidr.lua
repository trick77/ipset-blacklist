#!/usr/bin/lua
-- takes a list of CIDR ranges from stdin and removes duplicates and merges overlapping ranges and prints the list to stdout

require "bindechex"

function split(str, delim, maxNb)
    -- Eliminate bad cases...
    if string.find(str, delim) == nil then
        return { str }
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0    -- No limit
    end
    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local nb = 0
    local lastPos
    for part, pos in string.gfind(str, pat) do
        nb = nb + 1
        result[nb] = part
        lastPos = pos
        if nb == maxNb then break end
    end
    -- Handle the last field
    if nb ~= maxNb then
        result[nb + 1] = string.sub(str, lastPos)
    end
    return result
end

-- compare 2 cidr ranges, return true if a comes before b
function cmp_cidr(a, b)
	a_parts = split(a, "[\\/]+")
	b_parts = split(b, "[\\/]+")

	-- if cidr netmasks are the same, compare actual ranges
	if a_parts[2] == b_parts[2] then
		a_parts[1] = split(a_parts[1], "[\\.]+")
		b_parts[1] = split(b_parts[1], "[\\.]+")

		for i in pairs(a_parts[1]) do
			if a_parts[1][i] ~= b_parts[1][i] then
				return tonumber(a_parts[1][i]) > tonumber(b_parts[1][i])
			end
		end
	else
		return tonumber(a_parts[2]) < tonumber(b_parts[2])
	end
end

-- get list of ranges from stdin
function get_list()
	raw_list = {}
	for line in io.stdin:lines()
	do
		-- table.insert(raw_list, split(line, "[\\/]+"))
		table.insert(raw_list, line)
	end
	return raw_list
end

-- convert an IP address string & cidr range (eg. 192.168.1.0/24) to a 32bit binary string
function ip_to_bits(ip)
	bits = ""

	parts = split(ip, "[\\/\\.]+")
	for i = 1,4,1 do
		byte = bindechex.Dec2Bin(parts[i])
		bits_needed = 8 - (byte:len()%8)
		if bits_needed < 8 then
			for i = 1,(8-(byte:len()%8)),1 do
				byte = "0" .. byte
			end
		end
		bits = bits .. byte
	end

	return bits:sub(1, parts[5])
end

-- return true if cidr range 'outer' (eg "192.168.1.1/24") contains 'inner'
function range_contains(outer, inner)
	inner = ip_to_bits(inner)
	outer = ip_to_bits(outer)
	if outer:len() > inner:len() then
		print("ERROR: outer > inner")
		return false
	end

	for i = 1,#outer,1 do
		if outer:sub(i,i) ~= inner:sub(i,i) then
			return false
		end
	end

	return true
end

raw_list = get_list()

table.sort(raw_list, cmp_cidr)

for i in pairs(raw_list)
do
	for j=#raw_list,i+1,-1 do
		if range_contains(raw_list[i], raw_list[j]) then
			table.remove(raw_list, j)
		end
	end
end

for i in pairs(raw_list)
do
	print(raw_list[i])
end

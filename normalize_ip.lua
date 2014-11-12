#!/usr/bin/lua
-- normalize IP addresses (eg. convert 001.002.003.004 to 1.2.3.4, etc)

-- get list from stdin
function get_list()
	raw_list = {}
	for line in io.stdin:lines()
	do
		table.insert(raw_list, line)
	end
	return raw_list
end

function normalize_ip(ip)
	norm_parts = {}
	for part in string.gfind(ip, "[0-9]+")
	do
		table.insert(norm_parts, tostring(tonumber(part)))
	end

	ip = ""
	for i in pairs(norm_parts)
	do
		ip = ip .. "." .. norm_parts[i]
	end
	
	return string.sub(ip, 2)
end

list=get_list()
for i in pairs(list)
do
	print(normalize_ip(list[i]))
end

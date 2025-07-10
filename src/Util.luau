--!strict
--!native

local Util = {}

function Util.MergeTables<T>(t1: { T }, t2: { T }): { T }
	local newTable = {} :: { T }
	for k, v in t1 do
		newTable[k] = v
	end
	for k, v in t2 do
		newTable[k] = v
	end
	return newTable
end

return Util

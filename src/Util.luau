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

export type function NonNullable(t: type)
	assert(not t:is("nil"), "t must not be nil only")

	if t:is("union") then
		local newType: type
		for i, unionType in t:components() do
			if unionType:is("nil") then
				continue
			end
			newType = newType and types.unionof(newType, unionType) or unionType
		end
		return newType
	end

	return t
end

export type function valueof(tbl: type)
	assert(tbl:is("table"), "tbl must be a table")

	local valueUnion = nil

	for _, v in tbl:properties() do
		local read, write = v.read, v.write
		if read then
			valueUnion = valueUnion and types.unionof(valueUnion, read) or read
		end
		if write then
			valueUnion = valueUnion and types.unionof(valueUnion, write) or write
		end
	end

	return valueUnion
end

return Util

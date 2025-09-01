--!strict
--!native

local module = {}

export type function Enum(enumTbl: type)
	assert(enumTbl:is("table"), "Enum must be a table")

	local enum = types.newtable()

	for k, v in enumTbl:properties() do
		assert(k:is("singleton") and type(k:value()) == "string", "k must be a singleton string")
		assert(v.read ~= nil and v.read:is("singleton"), "v must be a singleton")
		enum:setreadproperty(k, v.read)
	end

	return enum
end

return table.freeze(module)

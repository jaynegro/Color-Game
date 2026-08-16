local currentRefs: { [number]: unknown }? = nil

local readRefs = {}

function readRefs.set(refs: { [number]: unknown }?)
	currentRefs = refs
end

function readRefs.get()
	return currentRefs
end

return readRefs

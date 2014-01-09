local META = {}

META.ClassName = "base"	
	
class.GetSet(META, "Pos", Vec3(0,0,0))
class.GetSet(META, "Angles", Ang3(0,0,0))
class.GetSet(META, "Scale", Vec3(1,1,1))
class.GetSet(META, "Size", 1)
class.GetSet(META, "ID", 0)

class.SetupParentingSystem(META)

function META:__init()
	if entities.world_entity then
		entities.world_entity:AddChild(self)
	end
	table.insert(entities.active_entities, self)
	self.ID = #entities.active_entities
end

function META:__tostring()
	return ("%s[%i]"):format(self.ClassName, self.ID)
end
	
function META:__index(key)
	if entities.is_keys[key] then
		return function() return entities.is_keys[key] == self.ClassName end
	end
end

function META:IsValid() return true end

function META:Remove(now)

	if not self.remove_me then
		table.insert(entities.remove_these, self)
		self.remove_me = true
	end
	
	if now then		
		self:OnRemove()
		self:RemoveChildren()
		
		if self:HasParent() then
			self:GetParent():RemoveChild(self)
		end
		
		for k,v in pairs(entities.active_entities) do
			if v == self then
				table.remove(entities.active_entities, k)
				break
			end
		end
		
		utilities.MakeNULL(self)		
	end
end

function META:Create(class_name)
	local ent = Entity(class_name)
	ent:SetParent(self)
	return ent
end

local not_implemented = function() end
META.OnRemove = not_implemented
	
entities.Register(META)
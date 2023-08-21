--  Enables animal mounts in fortress mode. Details in mod readme. Mount a gorlak! Mount a war-bear! Mount a dwarf!?
--
--[====[

mount_dwarf
================
]====]
function Mount (rider,horse)
  --for k,horse in pairs(unit_list) do
	--if unit_rider.pos.x==horse.pos.x and unit_rider.pos.y==horse.pos.y
	--and unit_rider.pos.z==horse.pos.z then --check if they are on the same tile
    	horse.general_refs:insert("#",{new=df.general_ref_unit_riderst,unit_id=rider.id})
    	rider.relationship_ids.RiderMount=horse.id
	rider.flags1.rider=true
	horse.flags1.ridden=true
	require("utils").insert_sorted(df.global.world.units.other.ANY_RIDER,rider,"id")
	return
end 

unit_1 = dfhack.gui.getSelectedUnit()
if unit_1 == nil then
	print ("You must place the cursor over the first target.")
	return
end

print("Target the Mount and press enter")
test = dfhack.lineedit("")

unit_2 = dfhack.gui.getSelectedUnit()
if unit_2 == nil then
	print ("You must place the cursor over the second target.")
	return
end


dfhack.with_suspend(Mount, unit_1, unit_2)
-- Pause and warn if a unit is starving
-- By Meneth32, PeridexisErrant, Lethosor
--@ module = true

starvingUnits = starvingUnits or {} --as:bool[]
dehydratedUnits = dehydratedUnits or {} --as:bool[]
sleepyUnits = sleepyUnits or {} --as:bool[]

function clear()
    starvingUnits = {}
    dehydratedUnits = {}
    sleepyUnits = {}
end

local gui = require 'gui'
local utils = require 'utils'
local widgets = require 'gui.widgets'
local units = df.global.world.units.active

local args = utils.invert({...})
if args.all or args.clear then
    clear()
end

local checkOnlySane = false
if args.sane then
    checkOnlySane = true
end

warning = defclass(warning, gui.ZScreen)
warning.ATTRS = {
    focus_path = 'warn-starving',
}

function warning:init(args)
    local main = widgets.Window{
        frame={w=80, h=18},
        frame_title='Warning',
        resizable=true,
        autoarrange_subviews=true
    }

    main:addviews{
        widgets.WrappedLabel{
            text_to_wrap=table.concat(args.messages, NEWLINE),
        }
    }

    self:addviews{main}
end

function warning:onDismiss()
    view = nil
end

local function findRaceCaste(unit)
    local rraw = df.creature_raw.find(unit.race)
    return rraw, safe_index(rraw, 'caste', unit.caste)
end

local function getSexString(sex)
  local sym = df.pronoun_type.attrs[sex].symbol
  if not sym then
    return ""
  end
  return "("..sym..")"
end

local function nameOrSpeciesAndNumber(unit)
    if unit.name.has_name then
        return dfhack.TranslateName(dfhack.units.getVisibleName(unit))..' '..getSexString(unit.sex),true
    else
        return 'Unit #'..unit.id..' ('..df.creature_raw.find(unit.race).caste[unit.caste].caste_name[0]..' '..getSexString(unit.sex)..')',false
    end
end

local function checkVariable(var, limit, description, map, unit)
    local rraw = findRaceCaste(unit)
    local species = rraw.name[0]
    local profname = dfhack.units.getProfessionName(unit)
    if #profname == 0 then profname = nil end
    local name = nameOrSpeciesAndNumber(unit)
    if var > limit then
        if not map[unit.id] then
            map[unit.id] = true
            return name .. ", " .. (profname or species) .. " is " .. description .. "!"
        end
    else
        map[unit.id] = false
    end
    return nil
end

function doCheck()
    local messages = {} --as:string[]
    for i=#units-1, 0, -1 do
        local unit = units[i]
        local rraw = findRaceCaste(unit)
        if rraw and dfhack.units.isActive(unit) and not dfhack.units.isOpposedToLife(unit) then
            if not checkOnlySane or dfhack.units.isSane(unit) then
                table.insert(messages, checkVariable(unit.counters2.hunger_timer, 75000, 'starving', starvingUnits, unit))
                table.insert(messages, checkVariable(unit.counters2.thirst_timer, 50000, 'dehydrated', dehydratedUnits, unit))
                table.insert(messages, checkVariable(unit.counters2.sleepiness_timer, 150000, 'very drowsy', sleepyUnits, unit))
            end
        end
    end
    if #messages > 0 then
        dfhack.color(COLOR_LIGHTMAGENTA)
        for _, msg in pairs(messages) do
            print(dfhack.df2console(msg))
        end
        dfhack.color()
        df.global.pause_state = true
        return warning{messages=messages}:show()
    end
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('warn-starving requires a map to be loaded')
end

view = view and view:raise() or doCheck()

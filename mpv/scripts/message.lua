-- Stolen from below
-- Mozbugbox's lua utilities for mpv 
-- Copyright (c) 2015-2018 mozbugbox@yahoo.com.au
-- Licensed under GPL version 3 or later

--[[
Show current time on video
Usage: b script-message-to message show-clock
--]]

local msg = require("mp.msg")
local utils = require("mp.utils") -- utils.to_string()
local assdraw = require('mp.assdraw')

local update_timeout = 10 -- in seconds
local timer = nil
local break_start = nil

function _show_clock()
    -- Show wall clock on bottom left corner
    local osd_w, osd_h, aspect = mp.get_osd_size()

    local scale = 1
    local fontsize = tonumber(mp.get_property("options/osd-font-size")) / scale
        fontsize = math.floor(fontsize)
    -- msg.info(fontsize)
    --
    --local now = os.date("%H:%M")
    local now = 'break time since '..break_start..' O wO'
    now = now .. '\\Nnow is '..os.date("%H:%M")
    local ass = assdraw:ass_new()
    ass:new_event()
    ass:an(5)
    ass:append(string.format("{\\fs%d}", fontsize))
    ass:append(now)
    ass:an(0)
    mp.set_osd_ass(osd_w, osd_h, ass.text)
    -- msg.info(ass.text, osd_w, osd_h)
end

function clear_osd()
    local osd_w, osd_h, aspect = mp.get_osd_size()
    mp.set_osd_ass(osd_w, osd_h, "")
end

function toggle_show_clock(v)
    if timer then
        clear_osd()
        timer:kill()
        timer = nil
    else
        break_start = os.date("%H:%M")
        _show_clock()
        timer = mp.add_periodic_timer(update_timeout, _show_clock)
    end
end

mp.register_script_message("show-clock", toggle_show_clock)


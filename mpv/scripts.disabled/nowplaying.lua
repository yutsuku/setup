local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'
local assdraw = require 'mp.assdraw'

local time_display = 10 -- how long the text will stay
local time_start = 5 -- how long to wait after playing new file
local time_end = 5 -- how long is the gap between text vanishing and video end

local timer_in = nil
local timer_out = nil
local is_visible = nil
local ov = nil


local FADE_NONE = -1
local FADE_IN = 0
local FADE_OUT = 1

local animation = {
    fps = 1/30,
    elapsed = 0,
    state = FADE_NONE,
    fade_in = 0.3,
    fade_out = 1
}

-- totally not a dirty hack
time_end = time_end+animation.fade_out+animation.fade_in

do
local state = {}
function fade_osd(osd_overlay, fade_state, callback)
    msg.debug(string.format('fade_osd: id = %d, state = %d', osd_overlay.id, fade_state))
    --osd_overlay:update()

    state[osd_overlay.id] = {
        fps = animation.fps,
        elapsed = 0,
        state = fade_state,
        fade_in = animation.fade_in,
        fade_out = animation.fade_out,
        data = osd_overlay.data
    }

    state[osd_overlay.id]['timer'] = mp.add_periodic_timer(state[osd_overlay.id]['fps'], function()
        state[osd_overlay.id]['elapsed'] = state[osd_overlay.id]['elapsed'] + state[osd_overlay.id]['fps']

        if state[osd_overlay.id]['elapsed'] >= state[osd_overlay.id]['fade_in'] then
            msg.debug(string.format('fade_osd done: id = %d, state = %d', osd_overlay.id, fade_state))
            osd_overlay.data = state[osd_overlay.id]['data']
            state[osd_overlay.id]['timer']:kill()

            if callback and type(callback) == 'function' then
                msg.info('fading - calling callback')
                callback()
            end

            return
        end

        local alpha = ''

        if fade_state == FADE_IN then
            alpha = string.format("{\\alpha&H%X}", 
                255 - ((state[osd_overlay.id]['elapsed'] / state[osd_overlay.id]['fade_in']) * 255)
            )
        elseif fade_state == FADE_OUT then
            alpha = string.format("{\\alpha&H%X}", 
                ((state[osd_overlay.id]['elapsed'] / state[osd_overlay.id]['fade_in']) * 255)
            )
        end

        osd_overlay.data = alpha..state[osd_overlay.id]['data']
        osd_overlay:update()

    end)
end
end

function show_message(message)
    message = string.gsub(message, '_', ' ')
    message = '{\\fnmpv-osd-symbols}\238\132\129 '..message
    write_osd(message)
end

function write_osd(message)
    if ov then
        msg.debug('osd overlay still exists, aborting adding new')
        return
    end
    msg.debug('adding osd overlay, message '..tostring(message))
    local osd_w, osd_h, aspect = mp.get_osd_size()

    local scale = 2
    local fontsize = tonumber(mp.get_property'options/osd-font-size') / scale
    fontsize = math.floor(fontsize)
    
    ov = mp.create_osd_overlay("ass-events")
    ov.data = ""
    ov.data = ov.data .. string.format("{\\an%d}", 1)
    --ov.data = ov.data .. string.format('{\\fs%d}', fontsize)
    ov.data = ov.data .. '{\\blur0\\bord1\\1c&HFFFFFF\\3c&H000000\\fs'..fontsize..'\\q2}'
    ov.data = ov.data .. message
    ov.data = ov.data .. string.format("{\\an%d}", 0)
    fade_osd(ov, FADE_IN)
    --ov:update()

    if timer_out then
        timer_out:kill()
    end
    
    timer_out = mp.add_timeout(time_display, function()
        msg.debug'timer_out'
        fade_osd(ov, FADE_OUT, function()
            msg.debug'removing osd overlay'
            ov:remove()
            ov = nil
            is_visible = nil
        end)
    end)
end

function observe_end(property, remaining)
    if not remaining then
        return
    end

    local fiilename, err = mp.get_property'filename/no-ext'

    if (not is_visible and remaining <= (time_display+time_end) and remaining > time_end) then
        msg.debug('time-remaining conditionds met')
        is_visible = true
        if not err then
            show_message(fiilename)
        end
    end
end

function file_loaded()
    cleanup()

    local duration = mp.get_property_native'duration'
    local fiilename, err = mp.get_property'filename/no-ext'

    msg.debug('loaded file, duration '..tostring(duration))
    
    -- skip short videos
    if (duration and duration < (((time_display * 2) + time_start + time_end) * 2)) then
        msg.debug'video duration too short, aboring'
        return
    end

    -- skip urls
    if string.match(mp.get_property_native'stream-open-filename', '://') then
        msg.debug'playing url, aborting'
        return
    end

    timer_in = mp.add_timeout(time_start, function()
        is_visible = true
        if not err then
            show_message(fiilename)
        end
    end)

    mp.observe_property('time-remaining', 'native', observe_end)
end

function file_end()
    mp.unobserve_property(observe_end)
    cleanup()
end

function cleanup()
    if ov then
        ov:remove()
        ov = nil
    end

    if timer_out then
        timer_out:kill()
        timer_out = nil
    end

    if timer_in then
        timer_in:kill()
        timer_in = nil
    end

    is_visible = nil
end

mp.register_event('file-loaded', file_loaded)
mp.register_event('end-file', file_end)
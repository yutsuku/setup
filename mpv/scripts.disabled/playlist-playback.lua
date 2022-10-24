--
-- Enables saving file position and playlist index when playing playlists (any)
-- Revision: 2021-05-31
-- Author: moh@yutsuku.net
--

local options = require 'mp.options'
local opt = {
    save_period = 30,
    min_files = 30
}

local function save_watch_later()
	mp.command("write-watch-later-config")
end

local save_period_timer = mp.add_periodic_timer(opt.save_period, save_watch_later)

options.read_options(opt)

local function process(value)
    save_period_timer:stop()

    if value >= opt.min_files then
        --mp.command("write-watch-later-config")
        save_period_timer:resume()
        mp.set_property("save-position-on-quit", "yes")
	end
end

local function file_loaded(event)
	process(mp.get_property_number("playlist-count", 0))
end

local function playlist_count(name, value)
	process(value)
end

mp.register_event("file-loaded", file_loaded)
mp.observe_property("playlist-count", "number", playlist_count)


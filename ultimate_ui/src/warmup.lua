-- warmup.lua
-- A queue of one-time set-up jobs (rasterize fonts, build the blurred menu background, ...) that
-- would otherwise run on the first frames you actually look at and freeze the window for a moment.
-- main.lua queues them and runs one every few frames WHILE THE INTRO VIDEO PLAYS; whatever is left
-- when the intro ends or is skipped is finished in one go. With no intro they all run at once.
--
--   warmup.add("main menu", function() ... end)     queue a job (errors are logged, never thrown)
--   warmup.update()                                 call every frame: runs the next job when it is due
--   warmup.finish()                                 run everything that is left, now
--   warmup.isDone()  warmup.clear()

local ROOT = (...):match("^(.*)%.[^.]+%.[^.]+$")   -- the library folder (this file lives in src/)
local debuglog = require(ROOT .. ".src.debuglog")

local warmup = {}

local jobs = {}
local nextJob = 1
local frames = 0

local START_AFTER = 6    -- frames to leave the video alone first, so it starts smoothly
local EVERY = 4          -- then one job every this many frames

function warmup.add(name, fn)
    jobs[#jobs + 1] = { name = name, fn = fn }
end

function warmup.clear()
    jobs, nextJob, frames = {}, 1, 0
end

function warmup.isDone()
    return nextJob > #jobs
end

local function run(job)
    local t0 = love.timer.getTime()
    local ok, err = pcall(job.fn)
    local ms = (love.timer.getTime() - t0) * 1000
    if ok then
        debuglog.log("warmup: %s (%.0f ms)", job.name, ms)
    else
        debuglog.warn("warmup: %s failed: %s", job.name, tostring(err))
    end
end

function warmup.update()
    if warmup.isDone() then return end
    frames = frames + 1
    if frames < START_AFTER or (frames - START_AFTER) % EVERY ~= 0 then return end
    local job = jobs[nextJob]
    nextJob = nextJob + 1
    run(job)
end

function warmup.finish()
    while not warmup.isDone() do
        local job = jobs[nextJob]
        nextJob = nextJob + 1
        run(job)
    end
end

return warmup

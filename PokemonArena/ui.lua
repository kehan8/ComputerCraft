-- ui.lua: all Basalt2 screen building + render functions (live/setup/
-- history screens). startup.lua owns the actual match/scan state (podiums,
-- teamSizes, matchState) and hands ui.build() references to it + one
-- callback (onStartBattle) for the one action that needs match/teamsizes
-- logic outside this file. Everything else (New Battle, History, Back,
-- Prev/Next paging, +/- team-size pickers) is self-contained here.
--
-- Battle-arena palette: soft blue/green/red via setPaletteColor (where
-- supported), rotating per-podium accent color (blue/red/green), a "VS"
-- pixel-art seam marker between exactly 2 podiums, a star-decorated WINNER
-- banner, and a configurable background (config.lua's BACKGROUND_COLOR).
--
-- Basalt2 gotcha (confirmed via GymArena/TicTacToe project memory): Label
-- elements never render a background in this Basalt2 build -- only Button
-- backgrounds do. Every decorative/colored panel below uses addButton(),
-- not addLabel().

local match = require("match")
local teamsizes = require("teamsizes")

local ui = {}

-- Softens a handful of named colors via setPaletteColor, if the given
-- terminal/monitor target supports it. `target` is the raw CC:Tweaked
-- term/monitor object (NOT the Basalt frame) -- setPaletteColor is a
-- term API method, not a Basalt one.
local function softenPalette(target)
    if not target or not target.setPaletteColor then
        return
    end
    pcall(function()
        target.setPaletteColor(colors.blue, 0x4A90D9)      -- soft battle blue (panels/accents)
        target.setPaletteColor(colors.lightBlue, 0xAFDCF7) -- pale sky blue (panel backgrounds)
        target.setPaletteColor(colors.green, 0x6FCF97)     -- soft green (positive/HP/accents)
        target.setPaletteColor(colors.red, 0xE0685F)       -- soft coral red (danger/VS/accents)
        target.setPaletteColor(colors.cyan, 0x7FD1C1)      -- soft teal (unused directly, kept close to the family)
    end)
end

-- Rotating per-podium accent color: podium 1 = blue, 2 = red, 3 = green, then repeats.
local HEADER_COLORS = { colors.blue, colors.red, colors.green }
local function headerColorFor(index)
    return HEADER_COLORS[((index - 1) % #HEADER_COLORS) + 1]
end

-- "VS" seam pixel-art: hand-drawn 11 (wide) x 5 (tall) bitmap per letter,
-- 1 = filled/black pixel. Same technique as GymArena/TicTacToe's
-- ICON_PATTERNS, drawn at 1:1 scale.
local VS_LETTER_COLS = 11
local VS_LETTER_ROWS = 5
local VS_GAP = 1 -- columns of gap opened between the V and S boxes when drawing
local VS_PATTERNS = {
    V = {
        {1,1,0,0,0,0,0,0,0,1,1},
        {0,1,1,0,0,0,0,0,1,1,0},
        {0,0,1,1,0,0,0,1,1,0,0},
        {0,0,0,1,1,0,1,1,0,0,0},
        {0,0,0,0,1,1,1,0,0,0,0},
    },
    S = {
        {1,1,1,1,1,1,1,1,1,1,1},
        {1,1,1,1,0,0,0,0,0,0,0},
        {1,1,1,1,1,1,1,1,1,1,1},
        {0,0,0,0,0,0,0,1,1,1,1},
        {1,1,1,1,1,1,1,1,1,1,1},
    },
}

-- WINNER banner: one line of text per row, split across 5 separate 1-row
-- buttons (bannerRows below) instead of one 5-row button with text only on
-- its centered line. Basalt centers button text horizontally by default,
-- so no manual column alignment is needed here.
local WINNER_BANNER_LINES = {
    "*    *    *    *    *",
    "  *    *    *    *",
    "* * *  WINNER  * * *",
    "  *    *    *    *",
    "*    *    *    *    *",
}

-- screen: the Basalt frame (computer main frame or Monitor-backed frame).
-- paletteTarget: raw term/monitor object for softenPalette(), or nil.
-- podiums: the live podium state tables (mutated elsewhere, read here).
-- teamSizes: array, index -> current team size (mutated in place by the
--            onStartBattle callback below; this module never replaces it).
-- historyEntries: the SAME table reference match.lua's state.historyEntries
--                 holds (history.lua mutates in place, so this stays valid for the run).
-- opts.historyMaxEntries, opts.backgroundColor, opts.onStartBattle(pendingSizesCopy)
function ui.build(screen, paletteTarget, podiums, teamSizes, historyEntries, opts)
    softenPalette(paletteTarget)

    local w, h = screen:getSize()

    -- All three screens (live/setup/history) share this one frame, so one
    -- call covers all of them. Falls back to light gray if opts doesn't provide one.
    screen:setBackground(opts.backgroundColor or colors.lightGray)

    -- ---------------------- COLUMN LAYOUT ----------------------
    -- Always edge-to-edge equal-width columns, no reserved center gutter.
    local colWidth = math.floor(w / #podiums)
    local BAR_WIDTH = math.max(4, colWidth - 4)
    -- Embed V/S into the header seam below -- only for exactly 2 podiums,
    -- and only if the pixel-art pattern plus the gap actually fit without
    -- overlapping the trainer name text.
    local showVs = (#podiums == 2) and (colWidth >= VS_LETTER_COLS + VS_GAP)

    local function columnFor(i)
        local x = (i - 1) * colWidth + 1
        local width = (i == #podiums) and (w - x + 1) or colWidth
        return x, width
    end

    local liveElements = {}
    local setupElements = {}
    local historyElements = {}

    local function setElementsVisible(elements, visible)
        for _, element in ipairs(elements) do
            element:setVisible(visible)
        end
    end

    local screenState = "live" -- "live", "setup", or "history"
    local function showScreen(state)
        screenState = state
        setElementsVisible(liveElements, state == "live")
        setElementsVisible(setupElements, state == "setup")
        setElementsVisible(historyElements, state == "history")
    end

    -- ---------------------- LIVE SCREEN ----------------------
    -- The podium card is vertically centered in the space above the bottom
    -- New Battle/History row, so it doesn't stay pinned to the top with a
    -- dead strip below it on a tall monitor.
    -- header(5) + trainer/name/bar/hp/fainted(5x1) + banner(5) = 15 rows --
    -- header/banner are 5 rows tall to match the VS pixel-art pattern's height.
    local HEADER_ROWS = 5
    local BANNER_ROWS = 5
    local PODIUM_CARD_ROWS = HEADER_ROWS + 5 + BANNER_ROWS
    local liveBodyHeight = h - 1 -- rows 1..(h-1); row h is New Battle/History
    local liveTop = 1 + math.max(0, math.floor((liveBodyHeight - PODIUM_CARD_ROWS) / 2))

    local podiumUI = {}

    for i, podium in ipairs(podiums) do
        local x, width = columnFor(i)
        local accent = headerColorFor(i)

        local ui_ = {}
        -- Header: colored accent bar (no "Left"/"Right" text) -- the
        -- trainer name label right below carries the same accent color.
        ui_.headerLabel = screen:addButton()
            :setText(""):setPosition(x, liveTop):setSize(width, HEADER_ROWS)
            :setBackground(accent):setForeground(colors.white)
        ui_.trainerLabel = screen:addButton()
            :setText(""):setPosition(x, liveTop + HEADER_ROWS):setSize(width, 1)
            :setBackground(colors.lightBlue):setForeground(accent)
        ui_.nameLabel = screen:addButton()
            :setText(""):setPosition(x, liveTop + HEADER_ROWS + 1):setSize(width, 1)
            :setBackground(colors.lightBlue):setForeground(colors.black)
        ui_.barLabel = screen:addButton()
            :setText(""):setPosition(x, liveTop + HEADER_ROWS + 2):setSize(width, 1)
            :setBackground(colors.lightBlue):setForeground(colors.black)
        ui_.hpLabel = screen:addButton()
            :setText(""):setPosition(x, liveTop + HEADER_ROWS + 3):setSize(width, 1)
            :setBackground(colors.lightBlue):setForeground(colors.black)
        ui_.faintedLabel = screen:addButton()
            :setText(""):setPosition(x, liveTop + HEADER_ROWS + 4):setSize(width, 1)
            :setBackground(colors.lightBlue):setForeground(colors.black)
        -- Winner banner: 5 separate 1-row buttons, one per WINNER_BANNER_LINES
        -- entry. bannerRows[3] is the "* * * WINNER * * *" middle line;
        -- foreground stays orange on all 5 rows (looks gold on the green background).
        ui_.bannerRows = {}
        for r = 1, BANNER_ROWS do
            local row = screen:addButton()
                :setText(""):setPosition(x, liveTop + HEADER_ROWS + 5 + (r - 1)):setSize(width, 1)
                :setBackground(colors.green):setForeground(colors.orange)
            ui_.bannerRows[r] = row
            liveElements[#liveElements + 1] = row
        end

        podiumUI[i] = ui_
        liveElements[#liveElements + 1] = ui_.headerLabel
        liveElements[#liveElements + 1] = ui_.trainerLabel
        liveElements[#liveElements + 1] = ui_.nameLabel
        liveElements[#liveElements + 1] = ui_.barLabel
        liveElements[#liveElements + 1] = ui_.hpLabel
        liveElements[#liveElements + 1] = ui_.faintedLabel
    end

    -- "VS" seam marker: pixel-art V/S bitmaps (VS_PATTERNS above), same
    -- "1 = filled pixel -> its own small addButton()" technique as
    -- GymArena/TicTacToe's icons. Both boxes are pulled VS_GAP columns away
    -- from the seam (V left, S right), opening a small strip of each
    -- podium's own header color in between. Only for exactly 2 podiums with
    -- a wide-enough column (see showVs above).
    if showVs then
        local x1, width1 = columnFor(1)
        local x2 = columnFor(2)
        local vx = x1 + width1 - VS_LETTER_COLS - VS_GAP
        local sx = x2 + VS_GAP

        local function drawVsLetter(pattern, startX)
            for pr = 1, VS_LETTER_ROWS do
                for pc = 1, VS_LETTER_COLS do
                    if pattern[pr][pc] == 1 then
                        local pixel = screen:addButton()
                            :setText("")
                            :setPosition(startX + pc - 1, liveTop + pr - 1):setSize(1, 1)
                            :setBackground(colors.black)
                        liveElements[#liveElements + 1] = pixel
                    end
                end
            end
        end

        drawVsLetter(VS_PATTERNS.V, vx)
        drawVsLetter(VS_PATTERNS.S, sx)
    end

    -- bottom row, split in half: New Battle (left) / History (right)
    local bottomHalf = math.floor(w / 2)
    local newBattleButton = screen:addButton()
        :setText("New Battle")
        :setPosition(1, h):setSize(bottomHalf, 1)
        :setBackground(colors.blue):setForeground(colors.white)
    liveElements[#liveElements + 1] = newBattleButton

    local historyButton = screen:addButton()
        :setText("History")
        :setPosition(bottomHalf + 1, h):setSize(w - bottomHalf, 1)
        :setBackground(colors.green):setForeground(colors.white)
    liveElements[#liveElements + 1] = historyButton

    -- ---------------------- SETUP SCREEN ----------------------
    local setupTitle = screen:addButton()
        :setText("New Battle - Team Size (1-6)")
        :setPosition(1, 1):setSize(w, 1)
        :setBackground(colors.blue):setForeground(colors.white)
    setupElements[#setupElements + 1] = setupTitle

    -- Vertically centered per-podium rows, same reasoning as the live
    -- screen's card centering.
    local SETUP_ROW_HEIGHT = 2 -- 1 content row + 1 blank spacer row
    local setupBodyHeight = h - 2 -- rows 2..(h-1): below title, above Start Battle
    local setupBlockHeight = #podiums * SETUP_ROW_HEIGHT
    local setupStartY = 2 + math.max(0, math.floor((setupBodyHeight - setupBlockHeight) / 2))

    local setupUI = {}
    local pendingTeamSizes = {} -- working copy edited on this screen

    for i, podium in ipairs(podiums) do
        local y = setupStartY + (i - 1) * SETUP_ROW_HEIGHT
        local accent = headerColorFor(i)
        setupUI[i] = {}

        -- "Trainer (...)" makes clear these are per-trainer size pickers
        -- while keeping the physical Left/Right orientation, generic over
        -- any podium count/position text.
        local label = screen:addButton()
            :setText("Trainer (" .. podium.position .. "):")
            :setPosition(2, y):setSize(math.max(4, w - 14), 1)
            :setBackground(colors.lightBlue):setForeground(accent)
        setupElements[#setupElements + 1] = label

        local minusButton = screen:addButton()
            :setText("-")
            :setPosition(w - 9, y):setSize(3, 1)
            :setBackground(colors.red):setForeground(colors.white)
            :onClick(function()
                pendingTeamSizes[i] = teamsizes.clamp(pendingTeamSizes[i] - 1)
                setupUI[i].countLabel:setText(tostring(pendingTeamSizes[i]))
            end)
        setupElements[#setupElements + 1] = minusButton

        setupUI[i].countLabel = screen:addButton()
            :setText("1")
            :setPosition(w - 6, y):setSize(3, 1)
            :setBackground(colors.blue):setForeground(colors.white)
        setupElements[#setupElements + 1] = setupUI[i].countLabel

        local plusButton = screen:addButton()
            :setText("+")
            :setPosition(w - 3, y):setSize(3, 1)
            :setBackground(colors.green):setForeground(colors.white)
            :onClick(function()
                pendingTeamSizes[i] = teamsizes.clamp(pendingTeamSizes[i] + 1)
                setupUI[i].countLabel:setText(tostring(pendingTeamSizes[i]))
            end)
        setupElements[#setupElements + 1] = plusButton
    end

    -- ---------------------- HISTORY SCREEN ----------------------
    -- Fixed, pre-drawn row slots (Basalt widgets should all exist before
    -- basalt.run() starts -- see ControlRoom/FossilLab), refilled per page
    -- rather than created/destroyed on demand.
    local historyTitle = screen:addButton()
        :setText("Match History (last " .. opts.historyMaxEntries .. ")")
        :setPosition(1, 1):setSize(w, 1)
        :setBackground(colors.blue):setForeground(colors.white)
    historyElements[#historyElements + 1] = historyTitle

    local HISTORY_ROWS_PER_PAGE = math.max(1, h - 3) -- row1 title, rows 2..h-2 list, h-1 pager, h back
    local historySlots = {}
    for i = 1, HISTORY_ROWS_PER_PAGE do
        historySlots[i] = screen:addButton()
            :setText("")
            :setPosition(1, 1 + i):setSize(w, 1)
            :setBackground(colors.lightBlue):setForeground(colors.black)
        historyElements[#historyElements + 1] = historySlots[i]
    end

    local historyPagerY = h - 1
    local historyPrevButton = screen:addButton()
        :setText("< Prev")
        :setPosition(1, historyPagerY):setSize(8, 1)
        :setBackground(colors.blue):setForeground(colors.white)
    historyElements[#historyElements + 1] = historyPrevButton

    local historyNextButton = screen:addButton()
        :setText("Next >")
        :setPosition(w - 7, historyPagerY):setSize(8, 1)
        :setBackground(colors.blue):setForeground(colors.white)
    historyElements[#historyElements + 1] = historyNextButton

    local historyPageLabel = screen:addButton()
        :setText("")
        :setPosition(10, historyPagerY):setSize(math.max(1, w - 18), 1)
        :setBackground(colors.lightBlue):setForeground(colors.black)
    historyElements[#historyElements + 1] = historyPageLabel

    local historyBackButton = screen:addButton()
        :setText("Back")
        :setPosition(1, h):setSize(w, 1)
        :setBackground(colors.blue):setForeground(colors.white)
        :onClick(function() showScreen("live") end)
    historyElements[#historyElements + 1] = historyBackButton

    local currentHistoryPage = 1

    local function totalHistoryPages()
        return math.max(1, math.ceil(#historyEntries / HISTORY_ROWS_PER_PAGE))
    end

    -- one line per match: "<time>  <who> F/T vs <who> F/T  -> <winner> won" (or
    -- "-> Draw" on a simultaneous mutual KO). Generic over any podium count.
    local function formatHistoryEntry(entry)
        local parts = {}
        for _, r in ipairs(entry.results) do
            local who = r.trainer or r.position
            parts[#parts + 1] = who .. " " .. r.fainted .. "/" .. r.teamSize
        end
        local outcome = entry.winner and (entry.winner .. " won") or "Draw"
        return (entry.time or "") .. "  " .. table.concat(parts, " vs ") .. "  -> " .. outcome
    end

    local function renderHistoryPage()
        local pages = totalHistoryPages()
        if currentHistoryPage > pages then currentHistoryPage = pages end
        if currentHistoryPage < 1 then currentHistoryPage = 1 end

        local startIndex = (currentHistoryPage - 1) * HISTORY_ROWS_PER_PAGE
        for i = 1, HISTORY_ROWS_PER_PAGE do
            local entry = historyEntries[startIndex + i]
            historySlots[i]:setText(entry and formatHistoryEntry(entry) or "")
        end
        if #historyEntries == 0 then
            historySlots[1]:setText("(no matches recorded yet)")
        end
        historyPageLabel:setText("Page " .. currentHistoryPage .. "/" .. pages)
    end

    historyPrevButton:onClick(function()
        currentHistoryPage = currentHistoryPage - 1
        renderHistoryPage()
    end)
    historyNextButton:onClick(function()
        currentHistoryPage = currentHistoryPage + 1
        renderHistoryPage()
    end)

    local function openHistoryScreen()
        currentHistoryPage = 1
        renderHistoryPage()
        showScreen("history")
    end
    historyButton:onClick(function() openHistoryScreen() end)

    -- ---------------------- LIVE RENDER ----------------------
    local function renderLive(matchWinnerIndex)
        for i, podium in ipairs(podiums) do
            local ui_ = podiumUI[i]
            local defeated = podium.faintedCount >= teamSizes[i]

            -- fainted tally color escalates with progress: black while
            -- nobody's down yet, orange partway through the team, red once
            -- the whole team's out.
            local faintedColor = colors.black
            if defeated then
                faintedColor = colors.red
            elseif podium.faintedCount > 0 then
                faintedColor = colors.orange
            end
            ui_.faintedLabel:setText("(" .. podium.faintedCount .. "/" .. teamSizes[i] .. " fainted)")
                :setForeground(faintedColor)

            if defeated then
                ui_.trainerLabel:setText("")
                ui_.nameLabel:setText("*** DEFEAT ***"):setForeground(colors.red)
                ui_.barLabel:setText("")
                ui_.hpLabel:setText("")
            else
                ui_.trainerLabel:setText(podium.lastTrainerName and ("Trainer: " .. podium.lastTrainerName) or "")

                if podium.lastName then
                    local nameText = podium.lastName
                    -- a fainted individual mon turns its name red too (matches "*** DEFEAT ***")
                    local isFainted = podium.lastHealth and podium.lastHealth <= 0
                    if isFainted then
                        nameText = nameText .. "  FAINTED"
                    end
                    ui_.nameLabel:setText(nameText):setForeground(isFainted and colors.red or colors.black)
                    ui_.barLabel:setText("[" .. match.healthBar(podium.lastHealth, podium.lastMaxHealth, BAR_WIDTH) .. "]")
                        :setForeground(match.hpColor(podium.lastHealth, podium.lastMaxHealth))
                    ui_.hpLabel:setText("HP " .. (podium.lastHealth or 0) .. "/" .. (podium.lastMaxHealth or 0))
                        :setForeground(match.hpColor(podium.lastHealth, podium.lastMaxHealth))
                else
                    ui_.nameLabel:setText("(no Pokemon detected)"):setForeground(colors.gray)
                    ui_.barLabel:setText("")
                    ui_.hpLabel:setText("")
                end
            end

            local isWinner = matchWinnerIndex == i
            for r = 1, #ui_.bannerRows do
                ui_.bannerRows[r]:setText(isWinner and WINNER_BANNER_LINES[r] or "")
            end
        end
    end

    -- ---------------------- SETUP FLOW ----------------------
    local function openSetupScreen()
        for i in ipairs(podiums) do
            pendingTeamSizes[i] = teamSizes[i]
            setupUI[i].countLabel:setText(tostring(pendingTeamSizes[i]))
        end
        showScreen("setup")
    end
    newBattleButton:onClick(function() openSetupScreen() end)

    local startBattleButton = screen:addButton()
        :setText("Start Battle")
        :setPosition(1, h):setSize(w, 1)
        :setBackground(colors.green):setForeground(colors.white)
        :onClick(function()
            local sizesCopy = {}
            for i in ipairs(podiums) do
                sizesCopy[i] = pendingTeamSizes[i]
            end
            opts.onStartBattle(sizesCopy)
            showScreen("live")
            renderLive(nil) -- a freshly reset match always has no winner yet
        end)
    setupElements[#setupElements + 1] = startBattleButton

    -- start with only the live screen visible
    setElementsVisible(setupElements, false)
    setElementsVisible(historyElements, false)

    return {
        showScreen = showScreen,
        getState = function() return screenState end,
        renderLive = renderLive,
        renderHistoryPage = renderHistoryPage,
        openSetupScreen = openSetupScreen,
        openHistoryScreen = openHistoryScreen,
    }
end

return ui

-- ui.lua: all Basalt2 screen building + render functions (live/setup/
-- history screens). Split out of startup.lua (session 8 module refactor).
-- startup.lua owns the actual match/scan state (podiums, teamSizes,
-- matchState) and just hands ui.build() references to it + one callback
-- (onStartBattle) for the one action that needs match/teamsizes logic
-- outside this file's concern. Everything else (New Battle, History,
-- Back, Prev/Next paging, +/- team-size pickers) is self-contained here
-- since it only touches UI-local state (current screen, pending sizes,
-- history page number) or mutates the podiums/teamSizes tables in place
-- (same references startup.lua holds, so changes are visible both ways
-- without extra plumbing).
--
-- Session 8 restyle (soft blue/green/red battle-arena palette, replacing
-- the old gray/lightGray/black/orange/cyan mix):
-- - setPaletteColor() stretch option: redefines what colors.blue/
--   lightBlue/green/red/cyan actually render as (softer/pastel RGB)
--   wherever the terminal supports it (Advanced Computer/Monitor, both
--   required by this project already -- see README). Wrapped in pcall
--   since this couldn't be tested locally; if the target doesn't support
--   it, the UI still works with CC's stock colors, just less "soft".
-- - Per-podium header: used to show the podium's position text ("Left"/
--   "Right"); now shows a plain colored accent bar instead (rotating
--   blue/red/green per podium index), and the trainer name label
--   (already shown one row below) is tinted with that same accent color
--   -- "color instead of text" and "trainer name" mix into one look
--   instead of being either/or.
-- - VS marker: originally a small red "VS" reserved in its own center
--   gutter column, but that disrupted the middle of the arena (user
--   feedback: not what was pictured -- see mockup in session notes). Now,
--   when there are EXACTLY 2 podiums, columns sit edge-to-edge (no
--   reserved gap) and a single-cell "V" is tucked into the right end of
--   podium 1's colored header bar, with "S" tucked into the left end of
--   podium 2's header bar -- the two letters sit flush against each other
--   at the seam, reading "VS" without stealing any board width. With 3+
--   podiums there's no single seam to put it at, so no V/S is shown.
-- - Frame background: explicit light gray (colors.lightGray) instead of
--   Basalt's default white, so the empty space around/below the podium
--   cards isn't stark white.
-- - Session 10 restyle (user mockup + feedback: header/VS "mogen wat
--   dikker" for balance, VS text should be black):
--   - The colored header bar (accent color, top of each podium card) and
--     the green winner banner (bottom of the card) both went from 1 row
--     tall to 3 rows tall ("triple regels/bar") -- thickening both the top
--     AND bottom bars keeps the card visually balanced instead of only
--     the top growing. The middle content rows (trainer/name/HP bar/HP
--     text/fainted count) are unchanged at 1 row each.
--   - The V/S seam letters grew to match the new 3-row header height
--     (same column, same accent background, just taller) and their
--     foreground changed from white to black per the mockup.
-- - Session 11 restyle (user feedback: "VS is toch niet meegegroeid" --
--   setSize() on a text button only thickens the colored background, a
--   single character glyph never scales with it; user proposed reusing
--   GymArena/TicTacToe's pixel-art icon technique instead, then hand-drew
--   an exact 11 (wide) x 5 (tall) bitmap per letter):
--   - VS_PATTERNS below holds that hand-drawn V/S bitmap verbatim (1 =
--     filled pixel). Same technique as TTT's ICON_PATTERNS: each filled
--     cell becomes its own small black addButton() layered on top of the
--     existing colored header bar; unfilled cells draw nothing, letting
--     the header's accent color show through underneath. Unlike TTT,
--     there's no per-cell scaling -- one pattern cell is exactly one
--     physical screen row/column, since HEADER_ROWS/BANNER_ROWS were
--     raised from 3 to 5 specifically to match the pattern's height ("dan
--     vergeet ook niet groen meegroeien" -- the banner grows with the
--     header again, same top/bottom balance reasoning as session 10).
--     PODIUM_CARD_ROWS is now 15 (5+5+5), was 11.
--   - The V's right edge sits flush against podium 1's right edge (the
--     seam) and the S's left edge sits flush against podium 2's left edge,
--     same seam position as sessions 9-10 -- just wide/tall enough to
--     read as actual letters instead of 1-character dots. showVs now also
--     requires colWidth >= 11 so the full-width pattern can't overlap the
--     trainer name text on a narrow screen; below that width no V/S is
--     drawn at all (same graceful-fallback pattern as the 3+ podium case).
-- - Session 12 (user feedback on session 11's V/S: overall very happy across
--   4 different monitor scales, but wanted a visible gap opened up between
--   the V and S -- "V gaat iets links en S gaat rechts" -- instead of the
--   two letters sitting flush against each other at the seam. (A first
--   attempt at this diagnosed the wrong problem -- monitor cell aspect
--   ratio -- and shrank the V's bitmap instead of moving it; reverted, see
--   below.) The actual fix: VS_PATTERNS.V is back to its original session
--   11 shape (full 11-column diagonal, right edge flush at the seam,
--   unchanged), and a new VS_GAP constant shifts the whole V box left and
--   the whole S box right by that many columns when drawing, opening a
--   small strip of each podium's own header color between the two letters
--   instead of touching. showVs now requires colWidth >= VS_LETTER_COLS +
--   VS_GAP so the widened footprint still can't overlap the trainer name
--   text on a narrow screen.
--
-- Basalt2 gotcha (confirmed via GymArena/TicTacToe project memory): Label
-- elements never render a background in this Basalt2 build -- only Button
-- backgrounds do. Every decorative/colored panel below uses addButton(),
-- not addLabel(), same fix already applied project-wide.

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

-- Rotating per-podium accent color: podium 1 = blue, 2 = red, 3 = green,
-- then repeats. Two podiums (the common case) reads as "blue side vs red
-- side", matching the V/S seam markers below.
local HEADER_COLORS = { colors.blue, colors.red, colors.green }
local function headerColorFor(index)
    return HEADER_COLORS[((index - 1) % #HEADER_COLORS) + 1]
end

-- "VS" seam pixel-art (session 11, see header comment): user-drawn 11
-- (wide) x 5 (tall) bitmap per letter, 1 = filled/black pixel. Same
-- technique as GymArena/TicTacToe's ICON_PATTERNS, drawn at 1:1 scale.
local VS_LETTER_COLS = 11
local VS_LETTER_ROWS = 5
-- Session 12: extra columns of gap opened between the V and S boxes when
-- drawing (see drawVsLetter call site below) -- purely a positioning
-- shift, not part of either bitmap.
local VS_GAP = 2
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

-- screen: the Basalt frame (computer main frame or Monitor-backed frame).
-- paletteTarget: raw term/monitor object for softenPalette(), or nil.
-- podiums: the live podium state tables (mutated elsewhere, read here).
-- teamSizes: array, index -> current team size (mutated in place by the
--            onStartBattle callback below; this module never replaces it).
-- historyEntries: the SAME table reference match.lua's state.historyEntries
--                 holds (history.lua mutates in place via table.insert/
--                 remove, so this reference stays valid for the whole run).
-- opts.historyMaxEntries, opts.onStartBattle(pendingSizesCopy)
function ui.build(screen, paletteTarget, podiums, teamSizes, historyEntries, opts)
    softenPalette(paletteTarget)

    local w, h = screen:getSize()

    -- Gray background instead of Basalt's default white -- see header
    -- comment. All three screens (live/setup/history) share this one
    -- frame, so one call covers all of them.
    screen:setBackground(colors.lightGray)

    -- ---------------------- COLUMN LAYOUT ----------------------
    -- Always edge-to-edge equal-width columns, no reserved center gutter
    -- (see header comment on the VS marker for why that was dropped).
    local colWidth = math.floor(w / #podiums)
    local BAR_WIDTH = math.max(4, colWidth - 4)
    -- Embed V/S into the header seam below -- only for exactly 2 podiums,
    -- and only if the pixel-art pattern plus the session 12 gap (11 + 2
    -- columns wide) actually fits a column without overlapping the trainer
    -- name text (session 11 / 12).
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
    -- The podium card (header/trainer/name/bar/hp/fainted/banner) is
    -- vertically centered in the space above the bottom New Battle/History
    -- row, so it doesn't stay pinned to the top with a dead strip below it
    -- on a tall monitor.
    -- header(5) + trainer/name/bar/hp/fainted(5x1) + banner(5) = 15 rows --
    -- see session 11 restyle comment above (header/banner raised from 3 to
    -- 5 rows to match the VS pixel-art pattern's height; was 11 rows total
    -- with a 3-row header/banner before that).
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
        -- Header: colored accent bar instead of the "Left"/"Right" text --
        -- the trainer name label right below carries the same accent color
        -- (see renderLive), so color + name work together as one header.
        -- 5 rows tall (session 11: raised from 3 to match the VS pixel-art
        -- pattern's height).
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
        -- Winner banner: also 5 rows tall (session 11: grew with the
        -- header again, same top/bottom balance reasoning as session 10).
        ui_.bannerLabel = screen:addButton()
            :setText(""):setPosition(x, liveTop + HEADER_ROWS + 5):setSize(width, BANNER_ROWS)
            :setBackground(colors.green):setForeground(colors.white)

        podiumUI[i] = ui_
        liveElements[#liveElements + 1] = ui_.headerLabel
        liveElements[#liveElements + 1] = ui_.trainerLabel
        liveElements[#liveElements + 1] = ui_.nameLabel
        liveElements[#liveElements + 1] = ui_.barLabel
        liveElements[#liveElements + 1] = ui_.hpLabel
        liveElements[#liveElements + 1] = ui_.faintedLabel
        liveElements[#liveElements + 1] = ui_.bannerLabel
    end

    -- "VS" seam marker (session 11): pixel-art V/S bitmaps (VS_PATTERNS,
    -- see module header comment), same "1 = filled pixel -> its own small
    -- addButton()" technique as GymArena/TicTacToe's icons. Session 12:
    -- both boxes are pulled VS_GAP columns away from the seam (V left,
    -- S right) instead of sitting flush against each other, opening a
    -- small strip of each podium's own header color in between. Only for
    -- exactly 2 podiums with a wide-enough column (see showVs above).
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
    -- screen's card centering (a tall monitor shouldn't leave a big dead
    -- strip below the pickers).
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

        local label = screen:addButton()
            :setText(podium.position .. ":")
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
    -- basalt.run() starts -- see ControlRoom/FossilLab, same convention),
    -- refilled per page rather than created/destroyed on demand.
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

            ui_.faintedLabel:setText("(" .. podium.faintedCount .. "/" .. teamSizes[i] .. " fainted)")

            if defeated then
                ui_.trainerLabel:setText("")
                ui_.nameLabel:setText("*** DEFEAT ***"):setForeground(colors.red)
                ui_.barLabel:setText("")
                ui_.hpLabel:setText("")
            else
                ui_.trainerLabel:setText(podium.lastTrainerName and ("Trainer: " .. podium.lastTrainerName) or "")

                if podium.lastName then
                    local nameText = podium.lastName
                    if podium.lastHealth and podium.lastHealth <= 0 then
                        nameText = nameText .. "  FAINTED"
                    end
                    ui_.nameLabel:setText(nameText):setForeground(colors.black)
                    ui_.barLabel:setText("[" .. match.healthBar(podium.lastHealth, podium.lastMaxHealth, BAR_WIDTH) .. "]")
                        :setForeground(match.hpColor(podium.lastHealth, podium.lastMaxHealth))
                    ui_.hpLabel:setText("HP " .. (podium.lastHealth or 0) .. "/" .. (podium.lastMaxHealth or 0))
                else
                    ui_.nameLabel:setText("(no Pokemon detected)"):setForeground(colors.gray)
                    ui_.barLabel:setText("")
                    ui_.hpLabel:setText("")
                end
            end

            ui_.bannerLabel:setText(matchWinnerIndex == i and "*** WINNER ***" or "")
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

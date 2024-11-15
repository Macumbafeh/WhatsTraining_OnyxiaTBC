--[[	file meta info
	@file 		WhatsTrainingUI.lua
	@brief		Functions to build the ingame UI window
--]]

--[[
	@brief		Accessing the addons private table

	@var 	_		addonName, thrown away
	@var	wt		Global addonTable
--]]
local _, wt = ...


-- @brief		"Constant" variables
local BOOKTYPE_SPELL =			BOOKTYPE_SPELL				-- Used to specify the players spellbook from in-game constant
local MAX_ROWS =				22							-- Max rows for the data shown in the spellbook
local ROW_HEIGHT =				14							-- Height of each row in the spellbook
local SKILL_LINE_TAB =			MAX_SKILLLINE_TABS - 1		-- Position for the addons tab in the spellbook
local HIGHLIGHT_TEXTURE_PATH =	"Interface\\AddOns\\WhatsTraining_Onyxia\\res\\highlight"
local LEFT_BG_TEXTURE_PATH =	"Interface\\AddOns\\WhatsTraining_Onyxia\\res\\left"
local RIGHT_BG_TEXTURE_PATH =	"Interface\\AddOns\\WhatsTraining_Onyxia\\res\\right"
local TAB_TEXTURE_PATH =		"Interface\\Icons\\INV_Misc_QuestionMark"


-- @brief	Creating the tooltip frame
local tooltip = CreateFrame("GameTooltip",				-- Type of frame
							"WhatsTrainingTooltip",		-- Name of frame, globally accessable
							UIParent,					-- Parent frame
							"GameTooltipTemplate")		-- Template to use building the frame
--[[
	@brief

	@param		spellInfo
--]]
local function setTooltip(spellInfo)
	tooltip:ClearLines()
	if (spellInfo.id) then
		tooltip:SetSpellByID(spellInfo.id)
	else
		tooltip:ClearLines()
	end
	if (spellInfo.cost > 0) then
		local coloredCoinString = spellInfo.formattedCost or
									  GetCoinTextureString(spellInfo.cost)
		if (GetMoney() < spellInfo.cost) then
			coloredCoinString = RED_FONT_COLOR_CODE .. coloredCoinString ..
									FONT_COLOR_CODE_CLOSE
		end
		local formatString = spellInfo.isHeader and
								 (spellInfo.costFormat or wt.L.TOTALCOST_FORMAT) or
								 wt.L.COST_FORMAT

		tooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE ..
							format(formatString, coloredCoinString) ..
							FONT_COLOR_CODE_CLOSE)
	end
	if (spellInfo.tooltip) then tooltip:AddLine(spellInfo.tooltip) end
	tooltip:Show()
end

local menuFrame = CreateFrame("Frame", "WTRightClickFrame", UIParent,
                              "UIDropDownMenuTemplate")
local function setRowSpell(row, spell)
	if (spell == nil) then
		row.currentSpell = nil
		row:Hide()
		return
	elseif (spell.isHeader) then
		row.spell:Hide()
		row.header:Show()
		row.header:SetText(spell.formattedName)
		row:SetID(0)
		row.highlight:SetTexture(nil)
	else
		local rowSpell = row.spell
		row.header:Hide()
		row.isHeader = false
		row.highlight:SetTexture(HIGHLIGHT_TEXTURE_PATH)
		rowSpell:Show()
		rowSpell.label:SetText(spell.name)
		rowSpell.subLabel:SetText(spell.formattedSubText)
		if (not spell.hideLevel) then
			rowSpell.level:Show()
			rowSpell.level:SetText(spell.formattedLevel)
			local color = spell.levelColor
			rowSpell.level:SetTextColor(color.r, color.g, color.b)
		else
			rowSpell.level:Hide()
		end
		row:SetID(spell.id)
		rowSpell.icon:SetTexture(spell.icon)
	end
	if (spell.click) then
		row:SetScript("OnClick", spell.click)
	elseif (not spell.isHeader) then
		row:SetScript("OnClick", function(_, button)
			if (not wt.ClickHook) then return end
			--if (button == "RightButton") then
		  wt.ClickHook(spell, function() wt:RebuildData()	end)
      --end
		end)
	else
		row:SetScript("OnClick", nil)
	end
	row.currentSpell = spell
	if (tooltip:IsOwned(row)) then setTooltip(spell) end
	row:Show()
end

-- When holding down left mouse on the slider knob, it will keep firing update even though
-- the offset hasn't changed so this will help throttle that
local lastOffset = -1
function wt.Update(frame, forceUpdate)
	local scrollBar = frame.scrollBar
	local offset = FauxScrollFrame_GetOffset(scrollBar)
	if (offset == lastOffset and not forceUpdate) then return end
	for i, row in ipairs(frame.rows) do
		local spellIndex = i + offset
		local spell = wt.data[spellIndex]
		setRowSpell(row, spell)
	end
	FauxScrollFrame_Update(wt.MainFrame.scrollBar, #wt.data, MAX_ROWS,
							ROW_HEIGHT, nil, nil, nil, nil, nil, nil, true)
	lastOffset = offset
end

local hasFrameShown = false
function wt.CreateFrame()
	local mainFrame = CreateFrame("Frame", "WhatsTrainingFrame", SpellBookFrame)
	mainFrame:SetPoint("TOPLEFT", SpellBookFrame, "TOPLEFT", 0, 0)
	mainFrame:SetPoint("BOTTOMRIGHT", SpellBookFrame, "BOTTOMRIGHT", 0, 0)
	mainFrame:SetFrameStrata("HIGH")
	local left = mainFrame:CreateTexture(nil, "ARTWORK")
	left:SetTexture(LEFT_BG_TEXTURE_PATH)
	left:SetWidth(256)
	left:SetHeight(512)
	left:SetPoint("TOPLEFT", mainFrame)
	local right = mainFrame:CreateTexture(nil, "ARTWORK")
	right:SetTexture(RIGHT_BG_TEXTURE_PATH)
	right:SetWidth(128)
	right:SetHeight(512)
	right:SetPoint("TOPRIGHT", mainFrame)
	mainFrame:Hide()

	local skillLineTab = _G["SpellBookSkillLineTab" .. SKILL_LINE_TAB]
--	hooksecurefunc("SpellBookFrame_UpdateSkillLineTabs", function()
	hooksecurefunc("SpellBookFrame_Update", function()
		skillLineTab:SetNormalTexture(TAB_TEXTURE_PATH)
		skillLineTab.tooltip = wt.L.TAB_TEXT
		skillLineTab:Show()
		if (SpellBookFrame.selectedSkillLine == SKILL_LINE_TAB) then
			skillLineTab:SetChecked(true)
			mainFrame:Show()
		else
			skillLineTab:SetChecked(false)
			mainFrame:Hide()
		end
	end)
	hooksecurefunc("SpellBookFrame_Update", function()
		if (SpellBookFrame.bookType ~= BOOKTYPE_SPELL) then
			mainFrame:Hide()
		elseif (SpellBookFrame.selectedSkillLine == SKILL_LINE_TAB) then
			mainFrame:Show()
		end
	end)

	local scrollBar = CreateFrame("ScrollFrame", "$parentScrollBar", mainFrame,
								  "FauxScrollFrameTemplate")
	scrollBar:SetPoint("TOPLEFT", 0, -75)
	scrollBar:SetPoint("BOTTOMRIGHT", -65, 81)
	scrollBar:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT,
										 function() wt.Update(mainFrame) end)
	end)
	scrollBar:SetScript("OnShow", function()
		if (not hasFrameShown) then
			wt:RebuildData()
			hasFrameShown = true
		end
		wt.Update(mainFrame, true)
	end)
	mainFrame.scrollBar = scrollBar

	local rows = {}
	for i = 1, MAX_ROWS do
		local row = CreateFrame("Button", "$parentRow" .. i, mainFrame)
		row:SetHeight(ROW_HEIGHT)
		row:EnableMouse(true)
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:SetScript("OnEnter", function(self)
			tooltip:SetOwner(self, "ANCHOR_RIGHT")
			setTooltip(self.currentSpell)
		end)
		row:SetScript("OnLeave", function() tooltip:Hide() end)

		local highlight = row:CreateTexture("$parentHighlight", "HIGHLIGHT")
		highlight:SetAllPoints()

		local spell = CreateFrame("Frame", "$parentSpell", row)
		spell:SetPoint("LEFT", row, "LEFT")
		spell:SetPoint("TOP", row, "TOP")
		spell:SetPoint("BOTTOM", row, "BOTTOM")

		local spellIcon = spell:CreateTexture(nil, "OVERLAY")
		spellIcon:SetPoint("TOPLEFT", spell)
		spellIcon:SetPoint("BOTTOMLEFT", spell)
		local iconWidth = ROW_HEIGHT
		spellIcon:SetWidth(iconWidth)
		local spellLabel = spell:CreateFontString("$parentLabel", "OVERLAY",
												  "GameFontNormal")
		spellLabel:SetPoint("TOPLEFT", spell, "TOPLEFT", iconWidth + 4, 0)
		spellLabel:SetPoint("BOTTOM", spell)
		spellLabel:SetJustifyV("MIDDLE")
		spellLabel:SetJustifyH("LEFT")
		local spellSublabel = spell:CreateFontString("$parentSubLabel",
													 "OVERLAY",
													 --"NewSubSpellFont")
													 "SpellFont_Small")
		-- test
		spellSublabel:SetTextColor(255/255, 255/255, 153/255)	-- Works!
		--test end
		spellSublabel:SetJustifyH("LEFT")
		spellSublabel:SetPoint("TOPLEFT", spellLabel, "TOPRIGHT", 2, 0)
		spellSublabel:SetPoint("BOTTOM", spellLabel)
		local spellLevelLabel = spell:CreateFontString("$parentLevelLabel",
													   "OVERLAY",
													   "GameFontWhite")
		spellLevelLabel:SetPoint("TOPRIGHT", spell, -4, 0)
		spellLevelLabel:SetPoint("BOTTOM", spell)
		spellLevelLabel:SetJustifyH("RIGHT")
		spellLevelLabel:SetJustifyV("MIDDLE")
		spellSublabel:SetPoint("RIGHT", spellLevelLabel, "LEFT")
		spellSublabel:SetJustifyV("MIDDLE")

		local headerLabel = row:CreateFontString("$parentHeaderLabel",
												 "OVERLAY", "GameFontWhite")
		headerLabel:SetAllPoints()
		headerLabel:SetJustifyV("MIDDLE")
		headerLabel:SetJustifyH("CENTER")

		spell.label = spellLabel
		spell.subLabel = spellSublabel
		spell.icon = spellIcon
		spell.level = spellLevelLabel
		row.highlight = highlight
		row.header = headerLabel
		row.spell = spell

		if (rows[i - 1] == nil) then
			row:SetPoint("TOPLEFT", mainFrame, 26, -78)
		else
			row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2)
		end
		row:SetPoint("RIGHT", scrollBar)

		rawset(rows, i, row)
	end
	mainFrame.rows = rows
	wt.MainFrame = mainFrame
end

wt.ClickHook = function(spell, afterClick)
  PlaySound(1115)
  afterClick()
  --[[ this section to manually marking tomes as "learnt" wasn't needed.
  -- left in case some sort of click functionality is needed in future.
  -- right now clicking a spell just reloads the learnt data
  local tomeId = spell.id
  local checked = wt.learnedPetAbilityMap[tomeId]
  local menu = {
    {text = spell.name, isTitle = true, classicChecks = true},
    {text = wt.L.TOME_HEADER, isTitle = true, classicChecks = true},
    {
      text = wt.L.TOME_LEARNED,
      checked = checked,
      func = function()
        PlaySound(1115)
        wt.learnedPetAbilityMap[tomeId] = not checked
        afterClick()
      end,
      isNotRadio = true
    },
  }
  EasyMenu(menu, menuFrame, "cursor", 10, 35, "MENU")--]]
end
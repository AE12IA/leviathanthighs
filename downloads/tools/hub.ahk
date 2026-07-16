#SingleInstance Force
#InstallKeybdHook
#UseHook On
#MaxThreadsPerHotkey 1
SendMode Input
SetKeyDelay, -1, -1
SetMouseDelay, -1
SetWinDelay, -1

; ===== THEME =====
cBg      := "16161e"
cSurface := "1e2030"
cCard    := "252836"
cBtn     := "5b9aff"
cAccent  := "7c9cff"
cSuccess := "4ade80"
cDanger  := "f87171"
cText    := "e8eaed"
cMuted   := "8b92a8"
cDim     := "5c6378"
fontUI   := "Segoe UI"

toggle := false
guiVisible := true
guiX := 20
guiY := 20
WIN_W := 320
WIN_H := 200
HDR_H := 40
SETTINGS_W := 320
SETTINGS_H := 428

; ===== SETTINGS FILE =====
settingsDir := A_ScriptDir . "\settings"
settingsFile := settingsDir . "\preferences.txt"

if !FileExist(settingsDir)
    FileCreateDir, %settingsDir%

currentBind := "9"
physicalKey := "r"
sBackwardKey := "0"
turn180Key := "7"
turnCycleKey := "z"
turnDirKey := "x"
turnAngleIndex := 1
turnEnabled := true
turnDirection := "right"
lastBind := ""
lastSBackward := ""
lastTurn180 := ""
lastTurnCycle := ""
lastTurnDir := ""
sBackwardEnabled := false

LoadSettings()
SetHotkey(currentBind)
SetSBackwardHotkey(sBackwardKey)
SetTurn180Hotkey(turn180Key)
SetTurnCycleHotkey(turnCycleKey)
SetTurnDirHotkey(turnDirKey)
BuildMainGui()
BuildSettingsGui()
ShowMainGui()
UpdatePhysicalStatus()
UpdateSBackwardStatus()
UpdateTurnStatus()
UpdateTurnOptionButtons()
return

; ===== GUI BUILDERS =====
AddHubButton(guiNum, x, y, w, h, label, handler) {
    global cBtn, cText, fontUI
    Gui, %guiNum%:Font, s9 c%cText%, %fontUI%
    Gui, %guiNum%:Add, Text, x%x% y%y% w%w% h%h% Center g%handler% Background%cBtn% +0x200, %label%
}

AddHubButtonVar(guiNum, x, y, w, h, label, handler, varName) {
    global cBtn, cText, fontUI
    Gui, %guiNum%:Font, s9 c%cText%, %fontUI%
    Gui, %guiNum%:Add, Text, x%x% y%y% w%w% h%h% Center v%varName% g%handler% Background%cBtn% +0x200, %label%
}

AddDragHeader(guiNum, title, dragHandler, dragW) {
    global HDR_H, cSurface, cText, cDim, fontUI

    Gui, %guiNum%:Add, Text, x0 y0 w%dragW% h%HDR_H% Background%cSurface% g%dragHandler%
    Gui, %guiNum%:Font, s8 c%cDim%, %fontUI%
    Gui, %guiNum%:Add, Text, x10 y13 w16 h14 Center g%dragHandler% BackgroundTrans, ⠿
    Gui, %guiNum%:Font, s11 Bold c%cText%, %fontUI%
    Gui, %guiNum%:Add, Text, x30 y12 w160 Left g%dragHandler% BackgroundTrans, %title%
}

BuildStatusCard(guiNum, x, y, w, h, title, dotVar, statusVar) {
    global cCard, cMuted, fontUI
    global PhysDot, StatusText, SBackDot, SBackStatus, TurnDot, TurnStatus

    lblX := x + 12
    valX := x + 32
    lblY := y + 12
    dotY := y + 30
    valY := y + 32

    Gui, %guiNum%:Add, Text, x%x% y%y% w%w% h%h% Background%cCard%
    Gui, %guiNum%:Font, s8 c%cMuted%, %fontUI%
    Gui, %guiNum%:Add, Text, x%lblX% y%lblY% w%w% BackgroundTrans, %title%
    Gui, %guiNum%:Font, s16 Bold cRed, %fontUI%
    Gui, %guiNum%:Add, Text, v%dotVar% x%lblX% y%dotY% w20 BackgroundTrans, ●
    Gui, %guiNum%:Font, s12 Bold cRed, %fontUI%
    Gui, %guiNum%:Add, Text, v%statusVar% x%valX% y%valY% w%w% BackgroundTrans, Inactive
}

BuildMainGui() {
    global cBg, cSurface, cCard, cAccent, cText, cMuted, cDim, fontUI
    global WIN_W, WIN_H, HDR_H
    global PhysDot, StatusText, SBackDot, SBackStatus, TurnDot, TurnStatus, TurnDirStatus

    mainX     := 16
    cardW     := 88
    card2X    := mainX + cardW + 12
    card3X    := card2X + cardW + 12
    btnW      := 28
    btnH      := 24
    btnY      := 8
    closeX    := WIN_W - btnW - 8
    settingsX := closeX - btnW - 6
    cardsY    := HDR_H + 8
    footerY   := WIN_H - 28

    Gui, 1:New
    Gui, 1:+AlwaysOnTop -Caption +ToolWindow
    Gui, 1:Color, %cBg%
    Gui, 1:Margin, 0, 0
    Gui, 1:Font, s9, %fontUI%

    AddDragHeader(1, "Niggas Hub", "GuiDrag", settingsX - 4)

    BuildStatusCard(1, mainX, cardsY, cardW, 72, "PHYSICAL", "PhysDot", "StatusText")
    BuildStatusCard(1, card2X, cardsY, cardW, 72, "S BACKWARD", "SBackDot", "SBackStatus")
    BuildStatusCard(1, card3X, cardsY, cardW, 72, "TURN", "TurnDot", "TurnStatus")
    turnLblX := card3X + 12
    turnValX := card3X + 32
    turnDirY := cardsY + 48
    Gui, 1:Font, s8 Bold cRed, %fontUI%
    Gui, 1:Add, Text, vTurnDirStatus x%turnValX% y%turnDirY% w56 BackgroundTrans, RIGHT

    footerW := WIN_W - 32
    Gui, 1:Font, s8 c%cDim%, %fontUI%
    Gui, 1:Add, Text, x%mainX% y%footerY% w140 Left BackgroundTrans, by foxy
    Gui, 1:Add, Text, x%mainX% y%footerY% w%footerW% Right BackgroundTrans, F8 to hide

    Gui, 1:Font, s10 c%cText%, %fontUI%
    Gui, 1:Add, Text, x%settingsX% y%btnY% w%btnW% h%btnH% Center gShowSettings Background%cBtn% +0x200, ⚙
    Gui, 1:Add, Text, x%closeX% y%btnY% w%btnW% h%btnH% Center gExitAppBtn Background%cBtn% +0x200, X
}

BuildSettingsGui() {
    global cBg, cSurface, cCard, cAccent, cText, cMuted, cDim, fontUI
    global SETTINGS_W, SETTINGS_H, HDR_H
    global currentBind, physicalKey, sBackwardKey, turn180Key, turnCycleKey, turnDirKey
    global BindLabel2, PhysLabel2, SBackLabel2, TurnLabel2, TurnCycleLabel2, TurnDirLabel2
    global TurnOnBtn, TurnOffBtn, TurnLeftBtn, TurnRightBtn

    mainX  := 16
    rowW   := SETTINGS_W - 32
    btnW   := 28
    btnH   := 24
    btnY   := 8
    backX  := SETTINGS_W - btnW - 8
    row1Y  := HDR_H + 8
    row2Y  := row1Y + 44
    row3Y  := row2Y + 44
    row4Y  := row3Y + 44
    row5Y  := row4Y + 44
    row6Y  := row5Y + 44
    row7Y  := row6Y + 44

    Gui, 2:New
    Gui, 2:+AlwaysOnTop -Caption +ToolWindow
    Gui, 2:Color, %cBg%
    Gui, 2:Margin, 0, 0
    Gui, 2:Font, s9, %fontUI%

    AddDragHeader(2, "Settings", "SettingsDrag", backX - 4)

    BuildSettingsRow(2, mainX, row1Y, rowW, "Toggle phy key", "BindLabel2", currentBind, "PickBind")
    BuildSettingsRow(2, mainX, row2Y, rowW, "Physical spam key", "PhysLabel2", physicalKey, "PickPhysical")
    BuildSettingsRow(2, mainX, row3Y, rowW, "Toggle backward key", "SBackLabel2", sBackwardKey, "PickSBackward")
    BuildSettingsRow(2, mainX, row4Y, rowW, "Turn key", "TurnLabel2", turn180Key, "PickTurn180")
    BuildSettingsRow(2, mainX, row5Y, rowW, "Turn cycle key", "TurnCycleLabel2", turnCycleKey, "PickTurnCycle")
    BuildSettingsRow(2, mainX, row6Y, rowW, "Turn direction key", "TurnDirLabel2", turnDirKey, "PickTurnDir")
    BuildTurnOptions(2, mainX, row7Y, rowW)

    Gui, 2:Font, s8 c%cDim%, %fontUI%
    hintY := SETTINGS_H - 24
    Gui, 2:Add, Text, x0 y%hintY% w%SETTINGS_W% Center BackgroundTrans, Esc to cancel

    Gui, 2:Font, s10 c%cText%, %fontUI%
    Gui, 2:Add, Text, x%backX% y%btnY% w%btnW% h%btnH% Center gBackToMain Background%cBtn% +0x200, ←
    Gui, 2:Hide
}

BuildTurnOptions(guiNum, x, y, rowW) {
    global cMuted, fontUI
    global TurnOnBtn, TurnOffBtn, TurnLeftBtn, TurnRightBtn

    btnY := y + 16

    Gui, %guiNum%:Font, s9 c%cMuted%, %fontUI%
    Gui, %guiNum%:Add, Text, x%x% y%y% w52 BackgroundTrans, Turn
    AddHubButtonVar(guiNum, x, btnY, 40, 24, "ON", "TurnSetOn", "TurnOnBtn")
    AddHubButtonVar(guiNum, x + 44, btnY, 40, 24, "OFF", "TurnSetOff", "TurnOffBtn")

    dirX := x + 100
    Gui, %guiNum%:Font, s9 c%cMuted%, %fontUI%
    Gui, %guiNum%:Add, Text, x%dirX% y%y% w56 BackgroundTrans, Direction
    AddHubButtonVar(guiNum, dirX, btnY, 48, 24, "LEFT", "TurnSetLeft", "TurnLeftBtn")
    AddHubButtonVar(guiNum, dirX + 52, btnY, 52, 24, "RIGHT", "TurnSetRight", "TurnRightBtn")
}

BuildSettingsRow(guiNum, x, y, rowW, label, varName, keyVal, handler) {
    global cCard, cAccent, cText, cMuted, fontUI
    global BindLabel2, PhysLabel2, SBackLabel2, TurnLabel2, TurnCycleLabel2, TurnDirLabel2

    badgeX := x
    btnX   := x + rowW - 72
    badgeY := y + 18
    btnY   := y + 18

    Gui, %guiNum%:Font, s9 c%cMuted%, %fontUI%
    Gui, %guiNum%:Add, Text, x%badgeX% y%y% w120 BackgroundTrans, %label%
    Gui, %guiNum%:Add, Text, x%badgeX% y%badgeY% w64 h24 Center v%varName% Background%cCard% c%cAccent%, %keyVal%
    AddHubButton(guiNum, btnX, btnY, 72, 24, "Change", handler)
}

ShowMainGui() {
    global guiX, guiY, WIN_W, WIN_H
    Gui, 1:Show, x%guiX% y%guiY% w%WIN_W% h%WIN_H%, Status
    WinActivate, Status
}

ShowSettingsGui() {
    global guiX, guiY, SETTINGS_W, SETTINGS_H
    Gui, 2:Show, x%guiX% y%guiY% w%SETTINGS_W% h%SETTINGS_H%, Settings
    WinActivate, Settings
}

CaptureGuiPos() {
    global guiX, guiY
    if WinExist("Status") {
        WinGetPos, guiX, guiY,,, Status
        SetTimer, SaveSettings, -300
    } else if WinExist("Settings") {
        WinGetPos, guiX, guiY,,, Settings
        SetTimer, SaveSettings, -300
    }
}

; ===== STATUS UPDATES =====
UpdatePhysicalStatus() {
    global toggle, PhysDot, StatusText
    if (toggle) {
        GuiControl, 1:+cGreen, PhysDot
        GuiControl, 1:, PhysDot, ●
        GuiControl, 1:+cGreen, StatusText
        GuiControl, 1:, StatusText, Active
    } else {
        GuiControl, 1:+cRed, PhysDot
        GuiControl, 1:, PhysDot, ●
        GuiControl, 1:+cRed, StatusText
        GuiControl, 1:, StatusText, Inactive
    }
}

UpdateSBackwardStatus() {
    global sBackwardEnabled, SBackDot, SBackStatus
    if (sBackwardEnabled) {
        GuiControl, 1:+cGreen, SBackDot
        GuiControl, 1:, SBackDot, ●
        GuiControl, 1:+cGreen, SBackStatus
        GuiControl, 1:, SBackStatus, Active
    } else {
        GuiControl, 1:+cRed, SBackDot
        GuiControl, 1:, SBackDot, ●
        GuiControl, 1:+cRed, SBackStatus
        GuiControl, 1:, SBackStatus, Inactive
    }
}

GetTurnAngleLabel() {
    global turnAngleIndex
    if (turnAngleIndex = 2)
        return "90°"
    if (turnAngleIndex = 3)
        return "45°"
    return "180°"
}

GetTurnDirectionLabel() {
    global turnDirection
    if (turnDirection = "left")
        return "LEFT"
    return "RIGHT"
}

GetTurnPixels() {
    global turnAngleIndex
    if (turnAngleIndex = 2)
        return 180
    if (turnAngleIndex = 3)
        return 90
    return 360
}

UpdateTurnStatus() {
    global turnEnabled, TurnDot, TurnStatus, TurnDirStatus
    if (turnEnabled) {
        angle := GetTurnAngleLabel()
        dir := GetTurnDirectionLabel()
        GuiControl, 1:+cGreen, TurnDot
        GuiControl, 1:, TurnDot, ●
        GuiControl, 1:+cGreen, TurnStatus
        GuiControl, 1:, TurnStatus, %angle%
        GuiControl, 1:+cGreen, TurnDirStatus
        GuiControl, 1:, TurnDirStatus, %dir%
    } else {
        GuiControl, 1:+cRed, TurnDot
        GuiControl, 1:, TurnDot, ●
        GuiControl, 1:+cRed, TurnStatus
        GuiControl, 1:, TurnStatus, Inactive
        GuiControl, 1:+cRed, TurnDirStatus
        GuiControl, 1:, TurnDirStatus, -
    }
}

UpdateTurnOptionButtons() {
    global turnEnabled, turnDirection, cBtn, cCard
    if (turnEnabled) {
        GuiControl, 2:+Background%cBtn%, TurnOnBtn
        GuiControl, 2:+Background%cCard%, TurnOffBtn
    } else {
        GuiControl, 2:+Background%cCard%, TurnOnBtn
        GuiControl, 2:+Background%cBtn%, TurnOffBtn
    }
    if (turnDirection = "left") {
        GuiControl, 2:+Background%cBtn%, TurnLeftBtn
        GuiControl, 2:+Background%cCard%, TurnRightBtn
    } else {
        GuiControl, 2:+Background%cCard%, TurnLeftBtn
        GuiControl, 2:+Background%cBtn%, TurnRightBtn
    }
}

SetKeyBadge(guiNum, varName, keyVal) {
    GuiControl, %guiNum%:, %varName%, %keyVal%
}

NormalizeKey(key) {
    StringLower, key, key
    return key
}

IsKeyDuplicate(newKey, field) {
    global currentBind, physicalKey, sBackwardKey, turn180Key, turnCycleKey, turnDirKey
    newKey := NormalizeKey(newKey)
    if (field != "toggle" && newKey = NormalizeKey(currentBind))
        return true
    if (field != "physical" && newKey = NormalizeKey(physicalKey))
        return true
    if (field != "sbackward" && newKey = NormalizeKey(sBackwardKey))
        return true
    if (field != "turn180" && newKey = NormalizeKey(turn180Key))
        return true
    if (field != "turncycle" && newKey = NormalizeKey(turnCycleKey))
        return true
    if (field != "turndir" && newKey = NormalizeKey(turnDirKey))
        return true
    return false
}

AssignKey(field, newKey) {
    global currentBind, physicalKey, sBackwardKey, turn180Key, turnCycleKey, turnDirKey

    if IsKeyDuplicate(newKey, field) {
        MsgBox, 48, Duplicate Key, That key is already assigned to another action.`nPlease choose a different key.
        return false
    }

    if (field = "toggle") {
        SetHotkey(newKey)
        currentBind := newKey
        SetKeyBadge(2, "BindLabel2", currentBind)
    } else if (field = "physical") {
        physicalKey := newKey
        SetKeyBadge(2, "PhysLabel2", physicalKey)
    } else if (field = "sbackward") {
        SetSBackwardHotkey(newKey)
        sBackwardKey := newKey
        SetKeyBadge(2, "SBackLabel2", sBackwardKey)
    } else if (field = "turn180") {
        SetTurn180Hotkey(newKey)
        turn180Key := newKey
        SetKeyBadge(2, "TurnLabel2", turn180Key)
    } else if (field = "turncycle") {
        SetTurnCycleHotkey(newKey)
        turnCycleKey := newKey
        SetKeyBadge(2, "TurnCycleLabel2", turnCycleKey)
    } else if (field = "turndir") {
        SetTurnDirHotkey(newKey)
        turnDirKey := newKey
        SetKeyBadge(2, "TurnDirLabel2", turnDirKey)
    }

    SaveSettings()
    return true
}

PromptKey(field) {
    ToolTip, Press a key for this bind...
    Input, newKey, L1 M V, {Escape}{Enter}
    ToolTip
    if (ErrorLevel = "EndKey:Escape" || newKey = "")
        return
    AssignKey(field, newKey)
}

; ===== SETTINGS I/O =====
LoadSettings() {
    global settingsFile, currentBind, physicalKey, sBackwardKey, turn180Key, turnCycleKey, turnDirKey, turnAngleIndex
    global turnEnabled, turnDirection, sBackwardEnabled, guiX, guiY

    if !FileExist(settingsFile)
        return

    FileRead, cfg, %settingsFile%
    Loop, Parse, cfg, `n, `r
    {
        line := A_LoopField
        if (line = "")
            continue
        StringSplit, kv, line, =
        key := kv1, val := kv2
        if (key = "toggle_key" && val != "")
            currentBind := val
        if (key = "physical_key" && val != "")
            physicalKey := val
        if (key = "s_backward_key" && val != "")
            sBackwardKey := val
        if (key = "turn_180_key" && val != "")
            turn180Key := val
        if (key = "turn_cycle_key" && val != "")
            turnCycleKey := val
        if (key = "turn_dir_key" && val != "")
            turnDirKey := val
        if (key = "turn_angle_index" && val != "")
            turnAngleIndex := val
        if (key = "turn_enabled" && val != "")
            turnEnabled := (val = "1")
        if (key = "turn_direction" && val != "")
            turnDirection := val
        if (key = "s_backward_enabled" && val != "")
            sBackwardEnabled := (val = "1")
        if (key = "gui_x" && val != "")
            guiX := val
        if (key = "gui_y" && val != "")
            guiY := val
    }
    if (turnAngleIndex < 1 || turnAngleIndex > 3)
        turnAngleIndex := 1
    if (turnDirection != "left")
        turnDirection := "right"
}

SaveSettings() {
    global settingsFile, currentBind, physicalKey, sBackwardKey, turn180Key, turnCycleKey, turnDirKey, turnAngleIndex
    global turnEnabled, turnDirection, sBackwardEnabled, guiX, guiY
    text := "toggle_key=" . currentBind . "`n"
        . "physical_key=" . physicalKey . "`n"
        . "s_backward_key=" . sBackwardKey . "`n"
        . "turn_180_key=" . turn180Key . "`n"
        . "turn_cycle_key=" . turnCycleKey . "`n"
        . "turn_dir_key=" . turnDirKey . "`n"
        . "turn_angle_index=" . turnAngleIndex . "`n"
        . "turn_enabled=" . (turnEnabled ? 1 : 0) . "`n"
        . "turn_direction=" . turnDirection . "`n"
        . "s_backward_enabled=" . (sBackwardEnabled ? 1 : 0) . "`n"
        . "gui_x=" . guiX . "`n"
        . "gui_y=" . guiY
    FileDelete, %settingsFile%
    FileAppend, %text%, %settingsFile%
}

SetHotkey(key) {
    global lastBind
    if (lastBind != "")
        Hotkey, % "~*" . lastBind, ToggleSpam, Off
    Hotkey, % "~*" . key, ToggleSpam, On
    lastBind := key
}

SetSBackwardHotkey(key) {
    global lastSBackward
    if (lastSBackward != "")
        Hotkey, % "$*" . lastSBackward, ToggleSBackward, Off
    Hotkey, % "$*" . key, ToggleSBackward, On
    lastSBackward := key
}

SetTurn180Hotkey(key) {
    global lastTurn180
    if (lastTurn180 != "")
        Hotkey, % "$*" . lastTurn180, TurnAction, Off
    Hotkey, % "$*" . key, TurnAction, On
    lastTurn180 := key
}

SetTurnCycleHotkey(key) {
    global lastTurnCycle
    if (lastTurnCycle != "")
        Hotkey, % "$" . lastTurnCycle, CycleTurnAngle, Off
    Hotkey, % "$" . key, CycleTurnAngle, On
    lastTurnCycle := key
}

SetTurnDirHotkey(key) {
    global lastTurnDir
    if (lastTurnDir != "")
        Hotkey, % "$" . lastTurnDir, ToggleTurnDirection, Off
    Hotkey, % "$" . key, ToggleTurnDirection, On
    lastTurnDir := key
}

TurnMouse() {
    global turnDirection
    total := GetTurnPixels()
    if (turnDirection = "left")
        total := -total
    dir := (total < 0) ? -1 : 1
    remaining := Abs(total)
    while (remaining > 0) {
        step := (remaining > 80) ? 80 : remaining
        DllCall("mouse_event", "UInt", 0x01, "Int", dir * step, "Int", 0, "UInt", 0, "UPtr", 0)
        remaining -= step
        Sleep, 1
    }
}

; ===== GUI HANDLERS =====
GuiDrag:
SettingsDrag:
    PostMessage, 0xA1, 2,,, A
    KeyWait, LButton
    CaptureGuiPos()
return

ShowSettings:
CaptureGuiPos()
Gui, 1:Hide
ShowSettingsGui()
UpdateTurnOptionButtons()
return

BackToMain:
CaptureGuiPos()
Gui, 2:Hide
ShowMainGui()
return

PickBind:
PromptKey("toggle")
return

PickPhysical:
PromptKey("physical")
return

PickSBackward:
PromptKey("sbackward")
return

PickTurn180:
PromptKey("turn180")
return

PickTurnCycle:
PromptKey("turncycle")
return

PickTurnDir:
PromptKey("turndir")
return

TurnSetOn:
turnEnabled := true
UpdateTurnStatus()
UpdateTurnOptionButtons()
SaveSettings()
return

TurnSetOff:
turnEnabled := false
UpdateTurnStatus()
UpdateTurnOptionButtons()
SaveSettings()
return

TurnSetLeft:
turnDirection := "left"
UpdateTurnStatus()
UpdateTurnOptionButtons()
SaveSettings()
return

TurnSetRight:
turnDirection := "right"
UpdateTurnStatus()
UpdateTurnOptionButtons()
SaveSettings()
return

ExitAppBtn:
Gosub, ExitHub
return

ExitHub:
CaptureGuiPos()
SaveSettings()
ExitApp
return

; ===== MACROS =====
ToggleSpam:
toggle := !toggle
if (toggle)
    SetTimer, SpamPhysical, 40
else
    SetTimer, SpamPhysical, Off
UpdatePhysicalStatus()
return

SpamPhysical:
if !toggle
    return
SendInput, {Blind}%physicalKey%
return

ToggleSBackward:
sBackwardEnabled := !sBackwardEnabled
UpdateSBackwardStatus()
SaveSettings()
return

TurnAction:
if !turnEnabled
    return
TurnMouse()
return

CycleTurnAngle:
global turnAngleIndex, turnEnabled
if !turnEnabled
    return
turnAngleIndex++
if (turnAngleIndex > 3)
    turnAngleIndex := 1
UpdateTurnStatus()
SaveSettings()
return

ToggleTurnDirection:
global turnEnabled, turnDirection
if !turnEnabled
    return
if (turnDirection = "left")
    turnDirection := "right"
else
    turnDirection := "left"
UpdateTurnStatus()
UpdateTurnOptionButtons()
SaveSettings()
return

#If (sBackwardEnabled)
$*s::
if GetKeyState("W", "P")
    KeyWait, w

if (toggle)
    SetTimer, SpamPhysical, Off

SendInput, {w down}{up down}
Sleep, 1
SendInput, {up up}{down down}

KeyWait, s
if GetKeyState("W", "P") {
    SendInput, {down up}{W up}{W down}
} else {
    SendInput, {down up}{w up}
}

if (toggle)
    SetTimer, SpamPhysical, 40
return
#If

F8::
guiVisible := !guiVisible
if (guiVisible)
    ShowMainGui()
else {
    CaptureGuiPos()
    Gui, 1:Hide
}
return

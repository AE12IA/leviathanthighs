#Requires AutoHotkey v2.0
#SingleInstance Force

ListLines(false)
ProcessSetPriority("High")

SetKeyDelay(-1, -1)
SetMouseDelay(-1)
SetWinDelay(-1)
SetControlDelay(-1)
SetDefaultMouseSpeed(0)


SetTimerResolution(5000)



if (!A_IsAdmin) {
    try {
        Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"')
    } catch {
        MsgBox("Run as admin...")
    }
    ExitApp()
}

ProcessSetPriority("High")


AppDir := A_AppData "\niggastrap"
if (!DirExist(AppDir))
    DirCreate(AppDir)

UserFlagsFile := AppDir "\user_flags.json"
SettingsFile  := AppDir "\user_settings.json"
SingletonDir := AppDir "\singleton"
if (!DirExist(SingletonDir))
    DirCreate(SingletonDir)
SingletonExe := SingletonDir "\niggastrapAHK.exe"

UserFlags      := []
AllOffsets     := Map()
AllPresetFlags := []
RobloxPID      := 0
SelectedRow    := 0
CurrentView    := "Main"
LogLines       := []
PrefixMap := Map()
global IsGuiHidden := false

; —— Auth (Leviathan) ——
AUTH_USERS_URL := "https://raw.githubusercontent.com/AE12IA/leviathanthighs/main/auth/users.json"
AUTH_API_URL   := "https://gentle-mouse-f361.fnaf22foxy.workers.dev"
AUTH_SALT      := "leviathan-auth-v1"
AuthSessionFile := AppDir "\auth_session.json"

RequireLogin()


WIN_W  := 1080
WIN_H  := 680
SB_W   := 54      
TB_H   := 55      
FT_H   := 55      


CX  := SB_W + 1          
CW  := WIN_W - CX        
BY  := TB_H + 1           
BH  := WIN_H - TB_H - FT_H - 2  
FY  := WIN_H - FT_H       


C_WIN   := "0x0A0A0B"
C_BODY  := "0x0F0F13"
C_TB    := "0x0C0C10"
C_FT    := "0x0C0C10"
C_PANEL := "0x13131A"
C_SEP   := "0x272735"
C_TXT   := "0xE6E6F0"
C_DIM   := "0x6A6A84"
C_SRCH  := "0x0A0A0E"
C_BLU   := "0x2979FF"
C_GRN   := "0x2E7D32"
C_RED   := "0xB71C1C"
C_PRP   := "0x6A1B9A"
C_ORG   := "0xE65100"


class ahhfuck {
    static PATTERN        := "48 83 EC 38 48 8B 0D ?? ?? ?? ?? 4C 8D 05"
    static hProcess       := 0
    static moduleBase     := 0
    static moduleSize     := 200 * 1024 * 1024
    static cached_sgl     := 0

    static Attach(pid) {
        if (this.hProcess) {
            DllCall("CloseHandle", "Ptr", this.hProcess)
            this.hProcess := 0
        }
        this.hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "UInt", pid, "Ptr")
        if (!this.hProcess)
            return false
        this.moduleBase := this.GetModuleBase(pid, "RobloxPlayerBeta.exe")
        this.cached_sgl := 0
        return (this.moduleBase != 0)
    }

    static GetModuleBase(pid, name) {
        snap := DllCall("CreateToolhelp32Snapshot", "UInt", 0x08, "UInt", pid, "Ptr")
        structSize := (A_PtrSize = 8) ? 1064 : 548
        mod32 := Buffer(structSize, 0)
        NumPut("UInt", structSize, mod32, 0)
        if DllCall("Module32First", "Ptr", snap, "Ptr", mod32) {
            loop {
                nameOffset := (A_PtrSize = 8) ? 48 : 32
                baseOffset := (A_PtrSize = 8) ? 24 : 20
                if (StrGet(mod32.ptr + nameOffset, "UTF-8") = name) {
                    base := NumGet(mod32.ptr + baseOffset, "Ptr")
                    DllCall("CloseHandle", "Ptr", snap)
                    return base
                }
                if !DllCall("Module32Next", "Ptr", snap, "Ptr", mod32)
                    break
            }
        }
        DllCall("CloseHandle", "Ptr", snap)
        return 0
    }

    static GetSingleton() {
        if (this.cached_sgl)
            return this.cached_sgl

        pats := StrSplit(this.PATTERN, " ")
        pLen := pats.Length
        pBuf := Buffer(pLen)
        mask := ""
        loop pLen {
            if (pats[A_Index] = "??") {
                NumPut("UChar", 0, pBuf, A_Index - 1)
                mask .= "?"
            } else {
                NumPut("UChar", Integer("0x" pats[A_Index]), pBuf, A_Index - 1)
                mask .= "x"
            }
        }

        mbi := Buffer(48, 0)
        addr := this.moduleBase
        stopAt := this.moduleBase + this.moduleSize

        while (addr < stopAt && DllCall("VirtualQueryEx", "Ptr", this.hProcess, "Ptr", addr, "Ptr", mbi, "UPtr", 48)) {
            vBase   := NumGet(mbi, 0, "Ptr")
            vSize   := NumGet(mbi, 24, "UPtr")
            state   := NumGet(mbi, 32, "UInt")
            protect := NumGet(mbi, 44, "UInt")

            if (state = 0x1000 && !(protect & 0x101)) {
                data := Buffer(vSize)
                if DllCall("ReadProcessMemory", "Ptr", this.hProcess, "Ptr", vBase, "Ptr", data.ptr, "UPtr", vSize, "Ptr", 0) {
                    ptr := data.ptr
                    loop (vSize - pLen) {
                        off   := A_Index - 1
                        found := true
                        loop pLen {
                            if (SubStr(mask, A_Index, 1) = "x") {
                                if (NumGet(ptr, off + A_Index - 1, "UChar") != NumGet(pBuf, A_Index - 1, "UChar")) {
                                    found := false
                                    break
                                }
                            }
                        }
                        if (found) {
                            fa := vBase + off
                            rel := this.ReadInt32(fa + 7)
                            this.cached_sgl := this.ReadUInt64(fa + 11 + rel)
                            return this.cached_sgl
                        }
                    }
                }
            }
            addr := vBase + vSize
        }
        return 0
    }

    static SetFlag(name, value) {
        sgl := this.GetSingleton()
        if (!sgl)
            return false

        hash := 0xcbf29ce484222325
        Loop Parse, name {
            hash := hash ^ Ord(A_LoopField)
            hash := Integer(hash * 0x100000001b3)
        }

        m_end  := this.ReadUInt64(sgl + 8)
        m_list := this.ReadUInt64(sgl + 24)
        m_mask := this.ReadUInt64(sgl + 48)
        if (!m_mask || !m_list)
            return false

        bucket := hash & m_mask
        node   := this.ReadUInt64(m_list + (bucket * 16) + 8)

        loop 300 {  
            if (node = m_end || node = 0)
                break

            entry := this.ReadMemory(node, 64)
            if (!entry)
                break

            str_sz  := NumGet(entry, 32, "Int64")
            str_alc := NumGet(entry, 40, "Int64")

            ename := (str_alc > 15)
                ? this.ReadString(NumGet(entry, 16, "Int64"), str_sz)
                : StrGet(entry.ptr + 16, str_sz, "UTF-8")

            if (ename == name) {
                vpr := NumGet(entry, 48, "Int64")
                if (!vpr)
                    return false

                vp := this.ReadUInt64(vpr + 0xC0)
                if (!vp)
                    return false

                v := StrLower(Trim(String(value)))

                if (v = "true" || v = "1") {
                    rv := 1
                } else if (v = "false" || v = "0") {
                    rv := 0
                } else if IsInteger(v) {
                    rv := Integer(v)
                } else {
                    return false
                }

                buf := Buffer(4)
                NumPut("Int", rv, buf)
                return DllCall("WriteProcessMemory", "Ptr", this.hProcess, "Ptr", vp, "Ptr", buf.ptr, "UPtr", 4, "Ptr", 0)
            }

            node := NumGet(entry, 8, "Int64")
        }

        return false
    }

    static ReadMemory(addr, size) {
        if (size <= 0 || size > 1048576) {  
            return 0
        }

        try {
            buf := Buffer(size, 0)
            if DllCall("ReadProcessMemory", "Ptr", this.hProcess, "Ptr", addr, "Ptr", buf.ptr, "UPtr", size, "Ptr", 0) {
                return buf
            }
            return 0
        } catch {
            return 0
        }
    }

    static ReadInt32(addr) => (b := this.ReadMemory(addr, 4)) ? NumGet(b, 0, "Int") : 0

    static ReadUInt64(addr) => (b := this.ReadMemory(addr, 8)) ? NumGet(b, 0, "Int64") : 0

    static ReadString(addr, sz) {
        max_sz := Min(sz, 8192) 
        if (max_sz <= 0)
            return ""

        b := this.ReadMemory(addr, max_sz)
        return b ? StrGet(b.ptr, max_sz, "UTF-8") : ""
    }
}

MyGui := Gui("-Caption +Border", "niggastrap")
MyGui.BackColor := C_WIN

opt := "x0 y0 w" SB_W " h" WIN_H " Background" C_WIN
MyGui.Add("Text", opt, "")

MyGui.SetFont("s6 Bold c" C_DIM, "Segoe UI")
opt := "x0 y10 w" SB_W " h14 BackgroundTrans Center"
MyGui.Add("Text", opt, "NIGGAS")
opt := "x0 y22 w" SB_W " h14 BackgroundTrans Center"
MyGui.Add("Text", opt, "AHK")


MyGui.SetFont("s15 c" C_DIM, "Segoe UI")
opt := "x0 y52 w" SB_W " h44 BackgroundTrans Center"
SideMain := MyGui.Add("Text", opt, Chr(0x2691))   
SideMain.OnEvent("Click", (*) => SwitchView("Main"))

MyGui.SetFont("s13 c" C_DIM, "Segoe UI")
opt := "x0 y104 w" SB_W " h44 BackgroundTrans Center"
SideLogs := MyGui.Add("Text", opt, Chr(0x25A4))    
SideLogs.OnEvent("Click", (*) => SwitchView("Logs"))

MyGui.SetFont("s13 c" C_DIM, "Segoe UI")
opt := "x0 y156 w" SB_W " h44 BackgroundTrans Center"
SideSet := MyGui.Add("Text", opt, Chr(0x2699))     
SideSet.OnEvent("Click", (*) => SwitchView("Settings"))


opt := "x" SB_W " y0 w1 h" WIN_H " Background" C_SEP
MyGui.Add("Text", opt, "")


opt := "x" CX " y0 w" CW " h" TB_H " Background" C_TB
MyGui.Add("Text", opt, "")

MyGui.SetFont("s15 Bold c" C_BLU, "Segoe UI")
opt := "x" (CX + 16) " y13 w260 h28 BackgroundTrans"
TTxt := MyGui.Add("Text", opt, "FFlags Editor")
TTxt.OnEvent("Click", (*) => PostMessage(0xA1, 2,,, "A"))


TBY := 13
TBH := 28
MyGui.SetFont("s9 Bold c" C_TXT, "Segoe UI")

opt := "x" (CX + 280) " y" TBY " w72 h" TBH " -Theme"
AddBtn := MyGui.Add("Button", opt, "+ Add")
AddBtn.OnEvent("Click", ShowAddDialog)

opt := "x" (CX + 358) " y" TBY " w86 h" TBH " -Theme"
RemBtn := MyGui.Add("Button", opt, "x Remove")
RemBtn.OnEvent("Click", RemoveSelected)

opt := "x" (CX + 450) " y" TBY " w104 h" TBH " -Theme"
RemAllBtn := MyGui.Add("Button", opt, "= Remove All")
RemAllBtn.OnEvent("Click", RemoveAllFlags)

opt := "x" (CX + 560) " y" TBY " w86 h" TBH " -Theme"
DataBaseBtn := MyGui.Add("Button", opt, "DataBase")
DataBaseBtn.OnEvent("Click", ShowDataBaseDialog)

opt := "x" (CX + 652) " y" TBY " w76 h" TBH " -Theme"
ImportBtn := MyGui.Add("Button", opt, " Import")
ImportBtn.OnEvent("Click", ShowImportDialog)

opt := "x" (CX + 734) " y" TBY " w76 h" TBH " -Theme"
ExportBtn := MyGui.Add("Button", opt, " Export")
ExportBtn.OnEvent("Click", ExportFlags)

MyGui.SetFont("s10 Bold c" C_TXT, "Segoe UI")
opt := "x" (WIN_W - 72) " y" 15 " w28 h28 Center BackgroundTrans"
MinBtn := MyGui.Add("Text", opt, Chr(0x2500))
MinBtn.OnEvent("Click", (*) => MyGui.Minimize())
opt := "x" (WIN_W - 40) " y" 13 " w28 h28 Center BackgroundTrans"
CloseBtn := MyGui.Add("Text", opt, "X")
CloseBtn.OnEvent("Click", (*) => ExitApp())
MyGui.OnEvent("Close", (*) => ExitApp())

opt := "x" CX " y" TB_H " w" CW " h1 Background" C_SEP
MyGui.Add("Text", opt, "")


opt := "x" CX " y" BY " w" CW " h" BH " Background" C_BODY
MyGui.Add("Text", opt, "")


SY := BY + 12

MyGui.SetFont("s10 Norm c" C_TXT, "Segoe UI")
opt := "x" (CX + 14) " y" SY " w" (CW - 28) " h30 Background" C_SRCH " c" C_TXT " +Border"
SearchBox := MyGui.Add("Edit", opt)
SearchBox.OnEvent("Change", (ed, *) => RefreshMainList(ed.Value))
SendMessage(0x1501, 1, StrPtr("Search flags..."), SearchBox.Hwnd)

HY := SY + 38
MyGui.SetFont("s8 Bold c" C_DIM, "Segoe UI")
opt := "x" (CX + 14) " y" HY " w40 h16 BackgroundTrans"
MyGui.Add("Text", opt, "#")
opt := "x" (CX + 56) " y" HY " w560 h16 BackgroundTrans"
MainHdrName := MyGui.Add("Text", opt, "NAME")
opt := "x" (CX + 624) " y" HY " w100 h16 BackgroundTrans"
MainHdrType := MyGui.Add("Text", opt, "TYPE")
vw := CW - 730
opt := "x" (CX + 730) " y" HY " w" vw " h16 BackgroundTrans"
MainHdrVal := MyGui.Add("Text", opt, "VALUE")
opt := "x" (CX + 14) " y" (HY + 18) " w" (CW - 28) " h1 Background" C_SEP
MainHdrSep := MyGui.Add("Text", opt, "")

LY := HY + 22
LH := BH - (LY - BY) - 8
LY := HY + 22
LH := BH - (LY - BY) - 8
opt := "x" (CX + 14) " y" LY " w" (CW - 28) " h" LH " Background" C_PANEL " c" C_TXT " +Border -Hdr Grid +Multi"
MainList := MyGui.Add("ListView", opt, ["#", "Name", "Type", "Value"])
MainList.OnEvent("Click", OnMainListClick)
MainList.ModifyCol(1, 38)
MainList.ModifyCol(2, 560)
MainList.ModifyCol(3, 90)
MainList.ModifyCol(4, "AutoHdr")

MainCtrls := [SearchBox, MainHdrName, MainHdrType, MainHdrVal, MainHdrSep, MainList]


MyGui.SetFont("s13 Bold c" C_TXT, "Segoe UI")
opt := "x" (CX + 20) " y" (BY + 14) " w300 h26 BackgroundTrans"
LogTitle := MyGui.Add("Text", opt, "Injection Logs")
LogTitle.Visible := false

MyGui.SetFont("s8 Norm c" C_DIM, "Segoe UI")
opt := "x" (CX + 14) " y" (BY + 42) " w" (CW - 28) " h1 Background" C_SEP
LogSep := MyGui.Add("Text", opt, "")
LogSep.Visible := false

MyGui.SetFont("s9 Bold c" C_TXT, "Segoe UI")
opt := "x" (CX + CW - 120) " y" (BY + 12) " w106 h26 -Theme"
ClearLogBtn := MyGui.Add("Button", opt, "Clear Logs")
ClearLogBtn.OnEvent("Click", ClearLogs)
ClearLogBtn.Visible := false

opt := "x" (CX + 14) " y" (BY + 50) " w" (CW - 28) " h" (BH - 58) " Background" C_PANEL " c" C_TXT " +Border -Hdr"
LogList := MyGui.Add("ListView", opt, ["Time", "Method", "Flag", "Status"])
LogList.ModifyCol(1, 80)
LogList.ModifyCol(2, 90)
LogList.ModifyCol(3, 560)
LogList.ModifyCol(4, "AutoHdr")
LogList.Visible := false

LogCtrls := [LogTitle, LogSep, ClearLogBtn, LogList]


MyGui.SetFont("s13 Bold c" C_TXT, "Segoe UI")
opt := "x" (CX + 20) " y" (BY + 14) " w400 h26 BackgroundTrans"
SetTitle := MyGui.Add("Text", opt, "Settings")
SetTitle.Visible := false

opt := "x" (CX + 14) " y" (BY + 42) " w" (CW - 28) " h1 Background" C_SEP
SetSepTop := MyGui.Add("Text", opt, "")
SetSepTop.Visible := false

MyGui.SetFont("s10 Norm c" C_TXT, "Segoe UI")
opt := "x" (CX + 14) " y" (BY + 52) " w" (CW - 28) " h78 Background" C_PANEL
SetCard1 := MyGui.Add("Text", opt, "")
SetCard1.Visible := false

opt := "x" (CX + 30) " y" (BY + 66) " w" (CW - 60) " c" C_TXT
UseSingleton := MyGui.Add("CheckBox", opt, "  Use Singleton Injection")
UseSingleton.OnEvent("Click", (*) => SaveSettings())
UseSingleton.Visible := false

MyGui.SetFont("s8 Norm c" C_DIM, "Segoe UI")
opt := "x" (CX + 52) " y" (BY + 90) " w" (CW - 80) " h14 BackgroundTrans"
USDesc := MyGui.Add("Text", opt, "Reads FFlags via Roblox's internal singleton pointer (recommended)")
USDesc.Visible := false

MyGui.SetFont("s10 Norm c" C_TXT, "Segoe UI")
opt := "x" (CX + 14) " y" (BY + 140) " w" (CW - 28) " h78 Background" C_PANEL
SetCard2 := MyGui.Add("Text", opt, "")
SetCard2.Visible := false

opt := "x" (CX + 30) " y" (BY + 154) " w" (CW - 60) " c" C_TXT
AutoApplyCB := MyGui.Add("CheckBox", opt, "  Auto-apply flags when Roblox launches")
AutoApplyCB.OnEvent("Click", (*) => SaveSettings())
AutoApplyCB.Visible := false

MyGui.SetFont("s8 Norm c" C_DIM, "Segoe UI")
opt := "x" (CX + 52) " y" (BY + 178) " w" (CW - 80) " h14 BackgroundTrans"
AADesc := MyGui.Add("Text", opt, "Automatically injects your flag list 4 seconds after Roblox is detected")
AADesc.Visible := false

opt := "x" (CX + 14) " y" (BY + 228) " w" (CW - 28) " h100 Background" C_PANEL
SetCard3 := MyGui.Add("Text", opt, "")
SetCard3.Visible := false

opt := "x" (CX + 30) " y" (BY + 242) " w" (CW - 60) " c" C_TXT
ReApplyCB := MyGui.Add("CheckBox", opt, "Re-Apply")
ReApplyCB.OnEvent("Click", (*) => (SaveSettings(), ManageReApplyTimer()))
ReApplyCB.Visible := false

MyGui.SetFont("s8 Norm c" C_DIM, "Segoe UI")
opt := "x" (CX + 52) " y" (BY + 266) " w" (CW - 80) " h30 BackgroundTrans"
RADesc := MyGui.Add("Text", opt, "Re-applies FFlags to keep them working.")
RADesc.Visible := false

SetCtrls := [SetTitle, SetSepTop, SetCard1, UseSingleton, USDesc, SetCard2, AutoApplyCB, AADesc, SetCard3, ReApplyCB, RADesc]


opt := "x" CX " y" FY " w" CW " h1 Background" C_SEP
MyGui.Add("Text", opt, "")
opt := "x" CX " y" (FY + 1) " w" CW " h" (FT_H - 1) " Background" C_FT
MyGui.Add("Text", opt, "")

MyGui.SetFont("s10 Bold c0x4CAF50", "Segoe UI")
opt := "x" (CX + 14) " y" (FY + 18) " w18 h20 BackgroundTrans"
StatusDot := MyGui.Add("Text", opt, Chr(0x25CF))
MyGui.SetFont("s9 Norm c" C_DIM, "Segoe UI")
opt := "x" (CX + 34) " y" (FY + 19) " w380 h18 BackgroundTrans"
StatusTxt := MyGui.Add("Text", opt, "Waiting for Roblox...")

FBY := FY + 12
opt := "x" (CX + CW - 452) " y" FBY " w136 h30 -Theme"
KillBtn := MyGui.Add("Button", opt, "x  Kill Roblox")
KillBtn.OnEvent("Click", (*) => KillRoblox())

opt := "x" (CX + CW - 306) " y" FBY " w150 h30 -Theme"
ApplyBtn := MyGui.Add("Button", opt, ">  Apply to Roblox")
ApplyBtn.OnEvent("Click", (*) => ApplyFlagsToRoblox(false))

opt := "x" (CX + CW - 144) " y" FBY " w130 h30 -Theme"
SaveBtn := MyGui.Add("Button", opt, "*  Save Flags")
SaveBtn.OnEvent("Click", (*) => (SaveUserFlags(), SetStatus("Flags saved!", "0x4CAF50"), SetTimer(() => SetStatus("Ready"), -2000)))

MyGui.Show("w" WIN_W " h" WIN_H)


; ===================== AUTH / LOGIN =====================
RequireLogin() {
    global AuthSessionFile
    if (HasValidSession())
        return

    result := ShowLoginDialog()
    if (result = "ok")
        return
    ExitApp()
}

HasValidSession() {
    global AuthSessionFile
    if (!FileExist(AuthSessionFile))
        return false
    try {
        data := JsonParseObj(FileRead(AuthSessionFile, "UTF-8"))
        if (!data.Has("username") || !data.Has("until"))
            return false
        expiresAt := data["until"]
        if (Type(expiresAt) = "String")
            expiresAt := DateParseUnix(expiresAt)
        if (expiresAt > UnixNow() && data["username"] != "")
            return true
    } catch {
    }
    return false
}

SaveSession(username) {
    global AuthSessionFile
    expiresAt := UnixNow() + (30 * 24 * 3600)
    text := '{`n'
        . '  "username": "' EscapeJson(username) '",`n'
        . '  "until": ' expiresAt '`n'
        . '}`n'
    try FileDelete(AuthSessionFile)
    FileAppend(text, AuthSessionFile, "UTF-8")
}

ShowLoginDialog() {
    global AUTH_USERS_URL, AUTH_API_URL
    L := Gui("-Caption +Border +AlwaysOnTop", "Leviathan Login")
    L.BackColor := "0x0A0A0B"
    L.SetFont("s16 Bold cWhite", "Segoe UI")
    L.Add("Text", "x24 y22 w320 h28 BackgroundTrans", "FFlag Login")
    L.SetFont("s9 c0x8A8A8A", "Segoe UI")
    L.Add("Text", "x24 y54 w320 h36 BackgroundTrans", "Use the account from the Leviathan Register page.")

    L.SetFont("s9 c0x8A8A8A", "Segoe UI")
    L.Add("Text", "x24 y104 w320 h18 BackgroundTrans", "Username")
    L.SetFont("s10 cWhite", "Segoe UI")
    userEdit := L.Add("Edit", "x24 y124 w320 h28 -Theme Background0x13131A")

    L.SetFont("s9 c0x8A8A8A", "Segoe UI")
    L.Add("Text", "x24 y166 w320 h18 BackgroundTrans", "Password")
    L.SetFont("s10 cWhite", "Segoe UI")
    passEdit := L.Add("Edit", "x24 y186 w320 h28 -Theme Password Background0x13131A")

    L.SetFont("s9 c0xF87171", "Segoe UI")
    errTxt := L.Add("Text", "x24 y228 w320 h36 BackgroundTrans", "")

    L.SetFont("s10 Bold cWhite", "Segoe UI")
    loginBtn := L.Add("Button", "x24 y274 w154 h34 -Theme", "Login")
    cancelBtn := L.Add("Button", "x190 y274 w154 h34 -Theme", "Exit")

    result := ""
    doLogin(*) {
        u := Trim(userEdit.Value)
        p := passEdit.Value
        if (u = "" || p = "") {
            errTxt.Value := "Enter username and password."
            return
        }
        errTxt.Value := "Checking…"
        try {
            VerifyLogin(u, p)
            SaveSession(u)
            result := "ok"
            L.Destroy()
        } catch as e {
            errTxt.Value := e.Message
        }
    }
    loginBtn.OnEvent("Click", doLogin)
    cancelBtn.OnEvent("Click", (*) => (result := "cancel", L.Destroy()))
    L.OnEvent("Close", (*) => (result := "cancel", L.Destroy()))
    passEdit.OnEvent("Change", (*) => "")
    L.Show("w368 h330")
    WinWaitClose(L)
    return result
}

VerifyLogin(username, password) {
    global AUTH_API_URL, AUTH_USERS_URL
    hwid := GetHardwareId()
    if (hwid = "")
        throw Error("Could not read PC hardware ID.")

    if (AUTH_API_URL != "") {
        body := '{"username":"' EscapeJson(username)
            . '","password":"' EscapeJson(password)
            . '","hwid":"' EscapeJson(hwid) '"}'
        resp := HttpRequest("POST", RTrim(AUTH_API_URL, "/") "/login", body, "application/json")
        if (InStr(resp, '"ok":true') || InStr(resp, '"ok": true'))
            return true
        if (InStr(resp, "locked to another") || InStr(resp, "another PC") || InStr(resp, "hardware"))
            throw Error("This account is locked to another PC.")
        if (InStr(resp, "Invalid"))
            throw Error("Invalid username or password.")
        throw Error("Login failed. Try again.")
    }

    ; Fallback (read-only): check password + existing hwid, cannot bind first time
    raw := HttpRequest("GET", AUTH_USERS_URL "?t=" UnixNow(), "", "")
    users := JsonParseArr(raw)
    for u in users {
        uname := u.Has("username") ? String(u["username"]) : ""
        pass := u.Has("password") ? String(u["password"]) : ""
        if (StrLower(uname) != StrLower(username) || pass != password)
            continue
        bound := u.Has("hwid") ? Trim(String(u["hwid"])) : ""
        if (bound = "")
            throw Error("Auth API required to bind this PC. Contact owner.")
        if (bound != hwid)
            throw Error("This account is locked to another PC.")
        return true
    }
    throw Error("Invalid username or password.")
}

GetHardwareId() {
    guid := ""
    try guid := RegRead("HKLM\SOFTWARE\Microsoft\Cryptography", "MachineGuid")
    catch {
        guid := ""
    }
    serial := ""
    try serial := String(DriveGetSerial("C:"))
    catch {
        serial := ""
    }
    raw := Trim(guid) "|" Trim(A_ComputerName) "|" Trim(serial)
    if (raw = "||" || raw = "")
        return ""
    try {
        return Sha256Hex(raw)
    } catch {
        clean := RegExReplace(raw, "[^A-Za-z0-9\-]", "")
        return SubStr(clean, 1, 64)
    }
}

HttpRequest(method, url, body := "", contentType := "") {
    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.Open(method, url, false)
    http.SetTimeouts(5000, 5000, 15000, 15000)
    if (contentType != "")
        http.SetRequestHeader("Content-Type", contentType)
    http.SetRequestHeader("User-Agent", "LeviathanFFlag/1.0")
    if (body != "")
        http.Send(body)
    else
        http.Send()
    return http.ResponseText
}

Sha256Hex(text) {
    inFile := A_Temp "\leviathan_auth_in.txt"
    outFile := A_Temp "\leviathan_auth_out.txt"
    psFile := A_Temp "\leviathan_auth_hash.ps1"
    try FileDelete(inFile)
    try FileDelete(outFile)
    try FileDelete(psFile)

    f := FileOpen(inFile, "w", "UTF-8-RAW")
    if (!f)
        throw Error("Cannot write hash input")
    f.Write(text)
    f.Close()

    ps := "$in = '" inFile "'`n"
        . "$out = '" outFile "'`n"
        . "$bytes = [IO.File]::ReadAllBytes($in)`n"
        . "$hash = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)`n"
        . "$hex = ([BitConverter]::ToString($hash)).Replace('-','').ToLower()`n"
        . "[IO.File]::WriteAllText($out, $hex)`n"
    FileAppend(ps, psFile, "UTF-8")

    RunWait('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' psFile '"', , "Hide")
    if (!FileExist(outFile))
        throw Error("Hash failed")
    return Trim(FileRead(outFile, "UTF-8"))
}

EscapeJson(str) {
    s := String(str)
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`t", "\t")
    return s
}

UnixNow() {
    return DateDiff(A_NowUTC, "19700101000000", "Seconds")
}

DateParseUnix(val) {
    if (Type(val) = "Integer" || Type(val) = "Float")
        return Integer(val)
    return Integer(val)
}

JsonParseArr(text) {
    text := Trim(text)
    if (SubStr(text, 1, 1) != "[")
        throw Error("users.json is not an array")
    ; lightweight array-of-objects parser for our auth file shape
    users := []
    pos := 2
    len := StrLen(text)
    while (pos <= len) {
        while (pos <= len && InStr(" `t`r`n,", SubStr(text, pos, 1)))
            pos += 1
        if (pos > len || SubStr(text, pos, 1) = "]")
            break
        if (SubStr(text, pos, 1) != "{")
            throw Error("Unexpected users.json format")
        obj := Map()
        pos += 1
        while (pos <= len) {
            while (pos <= len && InStr(" `t`r`n,", SubStr(text, pos, 1)))
                pos += 1
            if (SubStr(text, pos, 1) = "}") {
                pos += 1
                break
            }
            if (SubStr(text, pos, 1) != '"')
                throw Error("Expected key in users.json")
            key := JsonReadString(text, &pos)
            while (pos <= len && InStr(" `t`r`n", SubStr(text, pos, 1)))
                pos += 1
            if (SubStr(text, pos, 1) != ":")
                throw Error("Expected : in users.json")
            pos += 1
            while (pos <= len && InStr(" `t`r`n", SubStr(text, pos, 1)))
                pos += 1
            if (SubStr(text, pos, 1) = '"') {
                obj[key] := JsonReadString(text, &pos)
            } else {
                start := pos
                while (pos <= len && !InStr(",}", SubStr(text, pos, 1)))
                    pos += 1
                obj[key] := Trim(SubStr(text, start, pos - start))
            }
        }
        users.Push(obj)
    }
    return users
}

JsonParseObj(text) {
    text := Trim(text)
    if (SubStr(text, 1, 1) != "{")
        throw Error("Not an object")
    obj := Map()
    pos := 2
    len := StrLen(text)
    while (pos <= len) {
        while (pos <= len && InStr(" `t`r`n,", SubStr(text, pos, 1)))
            pos += 1
        if (SubStr(text, pos, 1) = "}")
            break
        if (SubStr(text, pos, 1) != '"')
            throw Error("Expected key")
        key := JsonReadString(text, &pos)
        while (pos <= len && InStr(" `t`r`n", SubStr(text, pos, 1)))
            pos += 1
        if (SubStr(text, pos, 1) != ":")
            throw Error("Expected :")
        pos += 1
        while (pos <= len && InStr(" `t`r`n", SubStr(text, pos, 1)))
            pos += 1
        if (SubStr(text, pos, 1) = '"') {
            obj[key] := JsonReadString(text, &pos)
        } else {
            start := pos
            while (pos <= len && !InStr(",}", SubStr(text, pos, 1)))
                pos += 1
            raw := Trim(SubStr(text, start, pos - start))
            obj[key] := IsNumber(raw) ? Number(raw) : raw
        }
    }
    return obj
}

JsonReadString(text, &pos) {
    ; pos at opening quote
    pos += 1
    out := ""
    len := StrLen(text)
    while (pos <= len) {
        ch := SubStr(text, pos, 1)
        if (ch = '"') {
            pos += 1
            return out
        }
        if (ch = "\" && pos < len) {
            n := SubStr(text, pos + 1, 1)
            if (n = '"')
                out .= '"'
            else if (n = "\")
                out .= "\"
            else if (n = "n")
                out .= "`n"
            else if (n = "r")
                out .= "`r"
            else if (n = "t")
                out .= "`t"
            else
                out .= n
            pos += 2
            continue
        }
        out .= ch
        pos += 1
    }
    throw Error("Unterminated string")
}


SwitchView(view) {
    global CurrentView := view

    isMain     := (view = "Main")
    isLogs     := (view = "Logs")
    isSettings := (view = "Settings")

    for c in MainCtrls
        c.Visible := isMain
    AddBtn.Visible     := isMain
    RemBtn.Visible     := isMain
    RemAllBtn.Visible  := isMain
    DataBaseBtn.Visible := isMain
    ImportBtn.Visible  := isMain
    ExportBtn.Visible  := isMain

    for c in LogCtrls
        c.Visible := isLogs

    for c in SetCtrls
        c.Visible := isSettings

    col_active := "c" C_BLU
    col_idle   := "c" C_DIM
    SideMain.SetFont(isMain     ? col_active : col_idle)
    SideLogs.SetFont(isLogs     ? col_active : col_idle)
    SideSet.SetFont(isSettings  ? col_active : col_idle)

    if (isMain)
        TTxt.Value := "FFlags Editor"
    else if (isLogs)
        TTxt.Value := "Injection Logs"
    else
        TTxt.Value := "Settings"
}


AddLog(method, flagName, status) {
    global LogLines
    t := FormatTime(, "HH:mm:ss")
    LogList.Insert(1,, t, method, flagName, status)
    LogLines.InsertAt(1, {time: t, method: method, flag: flagName, status: status})
}

ClearLogs(*) {
    global LogLines := []
    LogList.Delete()
}


RefreshMainList(filter := "") {
    MainList.Delete()
    MainList.Opt("-Redraw")
    idx := 0
    for flag in UserFlags {
        if (filter != "" && !InStr(flag["name"], filter, false))
            continue
        idx++
        MainList.Add(, idx, flag["name"], StrUpper(flag["type"]), flag["value"])
    }
    MainList.ModifyCol(4, "AutoHdr")
    MainList.Opt("+Redraw")
}

OnMainListClick(LV, row) {
    if (!row)
        return
    
    if (LV.GetCount("Selected") > 1)
        return
    global SelectedRow := row
    
    point := Buffer(8)
    DllCall("GetCursorPos", "Ptr", point)
    DllCall("ScreenToClient", "Ptr", LV.Hwnd, "Ptr", point)
    hitInfo := Buffer(24, 0)
    NumPut("Int", NumGet(point, 0, "Int"), hitInfo, 0)
    NumPut("Int", NumGet(point, 4, "Int"), hitInfo, 4)
    SendMessage(0x1039, 0, hitInfo.Ptr, LV.Hwnd)
    clickedCol := NumGet(hitInfo, 16, "Int")

    if (clickedCol == 3) {
        clickedFlagName := LV.GetText(row, 2)
        
        rect := Buffer(16, 0)
        NumPut("Int", 2, rect, 0)
        NumPut("Int", 3, rect, 4)
        SendMessage(0x1038, row-1, rect.Ptr, LV.Hwnd)
        
        clientPt := Buffer(8, 0)
        NumPut("Int", NumGet(rect, 0, "Int"), clientPt, 0)
        NumPut("Int", NumGet(rect, 4, "Int"), clientPt, 4)
        DllCall("ClientToScreen", "Ptr", LV.Hwnd, "Ptr", clientPt)
        
        X := NumGet(clientPt, 0, "Int"), Y := NumGet(clientPt, 4, "Int")
        W := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")
        H := NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")

        InlineEdit := Gui("-Caption +ToolWindow +Border")
        InlineEdit.BackColor := "0xFFFFFF"
        InlineEdit.SetFont("s9 c000000", "Segoe UI")
        
        currentVal := LV.GetText(row, 4)
        EditBox := InlineEdit.Add("Edit", "x0 y0 w" W " h" H " -VScroll -E0x200", currentVal)
        
        SaveAndClose(*) {
            newVal := EditBox.Value
            for index, flag in UserFlags {
                if (flag["name"] = clickedFlagName) {
                    flag["value"] := newVal
                    flag["type"] := InferType(newVal)
                    break
                }
            }
            SaveUserFlags()
            RefreshMainList(SearchBox.Value)
            InlineEdit.Destroy()
        }

        EditBox.OnEvent("LoseFocus", (*) => InlineEdit.Destroy())
        
        HotIfWinActive "ahk_id " InlineEdit.Hwnd
        Hotkey("Enter", SaveAndClose, "On")
        Hotkey("Escape", (*) => InlineEdit.Destroy(), "On")
        
        InlineEdit.Show("x" X " y" Y " w" W " h" H)
        SendMessage(0x00B1, 0, -1, EditBox.Hwnd)
    }
}
RemoveSelected(*) {
    row := 0
    selectedRows := []
    
    while (row := MainList.GetNext(row)) {
        selectedRows.Push(row)
    }
    
    if (selectedRows.Length = 0) {
        SetStatus("Nothing selected", "0xFF5252")
        return
    }

    i := selectedRows.Length
    while (i > 0) {
        idx := selectedRows[i]
        flagName := MainList.GetText(idx, 2)
        
        for uIdx, flag in UserFlags {
            if (flag["name"] == flagName) {
                UserFlags.RemoveAt(uIdx)
                break
            }
        }
        i--
    }
    
    SaveUserFlags()
    RefreshMainList(SearchBox.Value)
    SetStatus("Removed " selectedRows.Length " flags", "0xB71C1C")
    SetTimer(() => SetStatus("Ready"), -2000)
}

RemoveAllFlags(*) {
    ConfirmDlg := Gui("+Owner" MyGui.Hwnd " -Caption +Border")
    ConfirmDlg.BackColor := "0x0A0A0B"

    ConfirmDlg.Add("Text", "x0 y0 w400 h42 Background" C_TB, "")
    ConfirmDlg.Add("Text", "x0 y0 w4 h42 Background" C_RED, "") 
    ConfirmDlg.SetFont("s11 Bold c" C_TXT, "Segoe UI")
    ConfirmDlg.Add("Text", "x14 y10 w300 h24 BackgroundTrans", "Confirmation")
    ConfirmDlg.Add("Text", "x0 y42 w400 h1 Background" C_SEP, "")

    ConfirmDlg.SetFont("s10 Norm c" C_TXT, "Segoe UI")
    ConfirmDlg.Add("Text", "x20 y65 w360 Center", "Are you sure you want to remove ALL flags?")
    ConfirmDlg.SetFont("s9 c" C_DIM, "Segoe UI")
    ConfirmDlg.Add("Text", "x20 y85 w360 Center", "This action cannot be undone.")

    ConfirmDlg.SetFont("s9 Bold c" C_TXT, "Segoe UI")
    BtnYes := ConfirmDlg.Add("Button", "x75 y120 w120 h32 -Theme", "Yes, Remove All")
    BtnNo := ConfirmDlg.Add("Button", "x205 y120 w120 h32 -Theme", "Cancel")


    BtnNo.OnEvent("Click", (*) => ConfirmDlg.Destroy())
    
    OnConfirm(*) {
        global UserFlags := []
        SaveUserFlags()
        RefreshMainList()
        ConfirmDlg.Destroy()
        SetStatus("All flags removed", "0xB71C1C")
        SetTimer(() => SetStatus("Ready"), -3000)
    }

    BtnYes.OnEvent("Click", OnConfirm)

    ConfirmDlg.Show("w400 h170")
}


ShowAddDialog(*) {
    D := Gui("+Owner" MyGui.Hwnd " -Caption +Border")
    D.BackColor := "0x0A0A0B"

    D.Add("Text", "x0 y0 w460 h42 Background" C_TB, "")
    D.Add("Text", "x0 y0 w4 h42 Background" C_BLU, "")
    D.SetFont("s11 Bold c" C_TXT, "Segoe UI")
    D.Add("Text", "x14 y10 w300 h24 BackgroundTrans", "Add Flag")
    D.Add("Text", "x0 y42 w460 h1 Background" C_SEP, "")

    D.SetFont("s9 Norm c" C_DIM, "Segoe UI")
    D.Add("Text", "x14 y56 w120 h16 BackgroundTrans", "Flag Name")
    D.SetFont("s10 Norm c" C_TXT, "Segoe UI")
    FlagNameIn := D.Add("Edit", "x14 y74 w432 h28 Background" C_SRCH " c" C_TXT " +Border")

    D.SetFont("s9 Norm c" C_DIM, "Segoe UI")
    D.Add("Text", "x14 y112 w120 h16 BackgroundTrans", "Value")
    D.SetFont("s10 Norm c" C_TXT, "Segoe UI")
    FlagValIn := D.Add("Edit", "x14 y130 w432 h28 Background" C_SRCH " c" C_TXT " +Border")

    D.SetFont("s9 Bold c" C_TXT, "Segoe UI")
    BtnOK := D.Add("Button", "x14 y176 w110 h30 -Theme", "+ Add Flag")
    BtnOK.OnEvent("Click", (*) => DoAddFlag(FlagNameIn.Value, FlagValIn.Value, D))
    BtnC := D.Add("Button", "x132 y176 w80 h30 -Theme", "Cancel")
    BtnC.OnEvent("Click", (*) => D.Destroy())
    D.Show("w460 h220")
}

DoAddFlag(name, value, dlg) {
    name := Trim(name)
    if (name = "" || value = "")
        return
    UserFlags.Push(Map("name", name, "value", value, "type", InferType(value)))
    SaveUserFlags()
    RefreshMainList()
    dlg.Destroy()
}


ShowDataBaseDialog(*) {
    global PList, PValIn  

    P := Gui("+Owner" MyGui.Hwnd " -Caption +Border")
    P.BackColor := "0x0A0A0B"

    P.Add("Text", "x0 y0 w660 h46 Background" C_TB, "")
    P.Add("Text", "x0 y0 w4 h46 Background" C_PRP, "")
    
    P.SetFont("s12 Bold c" C_TXT, "Segoe UI")
    P.Add("Text", "x16 y12 w400 h24 BackgroundTrans", "Add Flag from DataBase")
    
    P.SetFont("s11 c" C_DIM, "Segoe UI")
    PX := P.Add("Button", "x620 y10 w28 h26 -Theme", "X")
    PX.OnEvent("Click", (*) => P.Destroy())

    P.Add("Text", "x0 y46 w660 h1 Background" C_SEP, "")

    P.SetFont("s10 Norm c" C_TXT, "Segoe UI")
    PSearch := P.Add("Edit", "x14 y60 w632 h30 Background" C_SRCH " c" C_TXT " +Border")
    SendMessage(0x1501, 1, StrPtr("Search DataBase..."), PSearch.Hwnd)

    PList := P.Add("ListView",
        "x14 y98 w632 h390 Background" C_PANEL " c" C_TXT " -Hdr +Border +Multi vDBList",
        ["Flag Name"])
    PList.ModifyCol(1, 618)

    for name in AllPresetFlags
        PList.Add(, name)

    PSearch.OnEvent("Change", (ed, *) => FilterPresetList(PList, ed.Value))
    PList.OnEvent("DoubleClick", (LV, row) => DoAddPresetDbl(LV, row, P))

    P.SetFont("s9 Norm c" C_DIM, "Segoe UI")
    P.Add("Text", "x14 y496 w50 h18 BackgroundTrans", "Value:")

    PValIn := P.Add("Edit", "x68 y492 w440 h28 Background" C_SRCH " c" C_TXT " +Border vDBValue")
    PValIn.Value := "true"

    P.SetFont("s9 Bold c" C_TXT, "Segoe UI")
    PAdd := P.Add("Button", "x516 y492 w130 h28 -Theme", "+ Add Selected")
    PAdd.OnEvent("Click", (*) => DoAddPresetBtn(PList, PValIn, P))

    HotIfWinActive "ahk_id " P.Hwnd
    Hotkey "^c", CopySelectedFromDatabase

    P.OnEvent("Close", (*) => (
        Hotkey("^c", "Off"),
        HotIfWinActive()   
    ))

    P.Show("w660 h534")
}



CopySelectedFromDatabase(thisHotkey) {

    guiObj := GuiFromHwnd(WinExist("A"))
    if (!guiObj)
        return


    listView := guiObj["DBList"]
    valEdit  := guiObj["DBValue"]

    if (!listView || !valEdit)
        return

    selectedRows := []
    row := 0
    while (row := listView.GetNext(row, "F")) {   
        selectedRows.Push(row)
    }

    if (selectedRows.Length = 0)
        return

    json := "{"
    count := 0

    for r in selectedRows {
        name     := listView.GetText(r, 1)
        prefixed := GetPrefixedName(name)
        value    := Trim(valEdit.Value)
        
        if (value = "")
            value := "true"

        json .= "`n    `"" prefixed "`": `"" value "`","
        count++
    }

    json := RTrim(json, ",") "`n}"

    if (count > 0) {
        A_Clipboard := json
        SetTimer(() => ToolTip(), -1400)
    }
}

FilterPresetList(LV, filter) {
    global AllPresetFlags
    LV.Opt("-Redraw")
    LV.Delete()
    for name in AllPresetFlags {
        if (filter = "" || InStr(name, filter, "Off"))
            LV.Add(, name)
    }
    LV.Opt("+Redraw")
}

DoAddPresetDbl(LV, row, dlg) {
    if (!row)
        return
    name := LV.GetText(row)
    UserFlags.Push(Map("name", name, "value", "true", "type", "bool"))
    SaveUserFlags()
    RefreshMainList()
    SetStatus("Added: " name, "0x4CAF50")
    SetTimer(() => SetStatus("Ready"), -2000)
}

DoAddPresetBtn(LV, valInputCtrl, parentGui) {

    desiredValue := Trim(valInputCtrl.Value)
    if (desiredValue = "") {
        MsgBox("Type FFlag's value ", "Icon!")
        return
    }

    selectedRows := []
    row := 0
    while (row := LV.GetNext(row)) {
        selectedRows.Push(row)
    }

    if (selectedRows.Length = 0) {
        MsgBox("Select at least 1 FFlag", "Iconi")
        return
    }

    addedCount := 0
    for row in selectedRows {
        flagName := LV.GetText(row, 1)  
        

        alreadyExists := false
        for existing in UserFlags {
            if (existing["name"] = flagName) {
                alreadyExists := true
                break
            }
        }
        
        if (alreadyExists)
            continue
            

        type := InferType(desiredValue)
        UserFlags.Push(Map("name", flagName, "value", desiredValue, "type", type))
        addedCount++
    }

    if (addedCount > 0) {
        SaveUserFlags()
        RefreshMainList(SearchBox.Value)
        SetStatus("Added " addedCount " FFlags from DataBase", "0x4CAF50")
        SetTimer(() => SetStatus("Ready"), -3000)
    } else {
        SetStatus("Already in list", "0xFFCA28")
    }

    ; parentGui.Destroy()
}


ShowImportDialog(*) {
    I := Gui("+Owner" MyGui.Hwnd " -Caption +Border")
    I.BackColor := "0x0A0A0B"

    I.Add("Text", "x0 y0 w520 h42 Background" C_TB, "")
    I.Add("Text", "x0 y0 w4 h42 Background" C_BLU, "")
    I.SetFont("s11 Bold c" C_TXT, "Segoe UI")
    I.Add("Text", "x14 y10 w300 h24 BackgroundTrans", "Import JSON")
    I.Add("Text", "x0 y42 w520 h1 Background" C_SEP, "")
    I.SetFont("s8 Norm c" C_DIM, "Segoe UI")
    I.Add("Text", "x14 y52 w492 h14 BackgroundTrans", 'Format: {"FFlagName": "value", "OtherFlag": "true"}')
    I.SetFont("s10 Norm c" C_TXT, "Segoe UI")
    JIn := I.Add("Edit", "x14 y70 w492 h160 Background" C_SRCH " c" C_TXT " +Border +Multi")
    I.SetFont("s9 Bold c" C_TXT, "Segoe UI")
    BtnImp := I.Add("Button", "x14 y242 w110 h30 -Theme", "^ Import")
    BtnImp.OnEvent("Click", (*) => ProcessJsonInput(JIn.Value, I))
    BtnFile := I.Add("Button", "x130 y242 w150 h30 -Theme", "[+] Import from Files")
    BtnFile.OnEvent("Click", (*) => (
        SelectedFile := FileSelect(3, , "Select JSON FFlags", "JSON Files (*.json)"),
        SelectedFile != "" ? ProcessJsonInput(FileRead(SelectedFile), I) : 0
    ))
    BtnC := I.Add("Button", "x295 y242 w80 h30 -Theme", "Cancel")
    BtnC.OnEvent("Click", (*) => I.Destroy())
    I.Show("w520 h286")
}

ProcessJsonInput(text, dlg) {
    count := 0
    pos   := 1
    while (pos := RegExMatch(text, '"(?P<Key>[^"]+)":\s*(?:"(?P<Val>[^"]*)"|(?P<ValNum>[^,\}\s]+))', &m, pos)) {
        key := m["Key"]
        val := (m["Val"] != "") ? m["Val"] : m["ValNum"]
        cleanKey := RegExReplace(key, "^(DFString|SFString|FString|DFFlag|SFFlag|DFInt|DFLog|FFlag|FInt|FLog|SFInt|Int)")
        exists := false
        for f in UserFlags {
            if (f["name"] = cleanKey) {
                f["value"] := val
                exists := true
                break
            }
        }
        if (!exists)
            UserFlags.Push(Map("name", cleanKey, "value", val, "type", InferType(val)))
        count++
        pos += m.Len
    }
    if (count > 0) {
        SaveUserFlags()
        RefreshMainList()
        dlg.Destroy()
        SetStatus("Imported " count " flag(s)", "0x4CAF50")
        SetTimer(() => SetStatus("Ready"), -3000)
    }
}


ExportFlags(*) {
    if (UserFlags.Length = 0) {
        MsgBox("No flags to export.", "Export", 0x40)
        return
    }
    path := FileSelect("S16",, "Export FFlags", "JSON Files (*.json)")
    if (path = "")
        return
    
    if !RegExMatch(path, "i)\.json$")
        path .= ".json"

    json := "{"
    for f in UserFlags {
        pName := GetPrefixedName(f["name"])
        json .= "`n    `"" pName "`": `"" f["value"] "`","
    }
    json := RTrim(json, ",") "`n}"
    try {
        FileOpen(path, "w", "UTF-8").Write(json)
        SetStatus("Exported " UserFlags.Length " flags", "0x4CAF50")
        SetTimer(() => SetStatus("Ready"), -4000)
    }
}


ApplyFlagsToRoblox(isAuto := false) {
    global RobloxPID, UserFlags, AllOffsets
    if (!RobloxPID) {
        SetStatus("Roblox not detected!", "0xFF5252")
        return
    }

    method    := UseSingleton.Value ? "Singleton" : "Offsets"
    succCount := 0
    failCount := 0

    if (UseSingleton.Value) {
        sgl      := 0
        maxTries := isAuto ? 15 : 1
        loop maxTries {
            sgl := ahhfuck.GetSingleton()
            if (sgl)
                break
            if (isAuto) {
                SetStatus("Waiting for singleton " A_Index "/" maxTries, "0xFFCA28")
                Sleep(500)
            }
        }
        if (!sgl) {
            SetStatus("Singleton not found!", "0xFF5252")
            AddLog("Singleton", "—", "FAILED: singleton not found")
            return
        }
        for flag in UserFlags {
            ok := ahhfuck.SetFlag(flag["name"], flag["value"])
            if (ok) {
                succCount++
                AddLog("Singleton", flag["name"], "OK  ->  " flag["value"])
            } else {
                failCount++
                AddLog("Singleton", flag["name"], "FAILED")
            }
        }
    } else {
        for flag in UserFlags {
            if (AllOffsets.Has(flag["name"])) {
                addr := ahhfuck.moduleBase + AllOffsets[flag["name"]]
                ok   := WriteRawMemory(addr, flag["value"], flag["type"])
                if (ok) {
                    succCount++
                    AddLog("Offsets", flag["name"], "OK  ->  " flag["value"])
                } else {
                    failCount++
                    AddLog("Offsets", flag["name"], "FAILED")
                }
            } else {
                failCount++
                AddLog("Offsets", flag["name"], "FAILED: no offset")
            }
        }
    }

    total := UserFlags.Length
    AddLog(method, "— SUMMARY —", "Applied " succCount "/" total " flags  (" failCount " failed)")
    SetStatus("Applied " succCount "/" total " via " method, "0x4CAF50")
    SetTimer(() => SetStatus("Ready"), -5000)
}

WriteRawMemory(addr, value, type) {
    if (!ahhfuck.hProcess || !addr)
        return false
    try {
        buf := Buffer(8, 0)
        sz  := 0
        if (type = "bool") {
            v := (StrLower(String(value)) = "true" || value = "1") ? 1 : 0
            NumPut("Char", v, buf)
            sz := 1
        } else if (type = "int") {
            NumPut("Int", Integer(value), buf)
            sz := 4
        } else if (type = "float") {
            NumPut("Double", Float(value), buf)
            sz := 8
        } else {
            sv  := String(value)
            sz  := StrPut(sv, "UTF-8")
            buf := Buffer(sz, 0)
            StrPut(sv, buf, "UTF-8")
        }
        return DllCall("WriteProcessMemory", "Ptr", ahhfuck.hProcess, "Ptr", addr, "Ptr", buf.Ptr, "UInt", sz, "Ptr", 0)
    } catch {
        return false
    }
}

KillRoblox() {
    ProcessClose("RobloxPlayerBeta.exe")
    AddLog("System", "RobloxPlayerBeta.exe", "Process killed")
    SetStatus("Roblox killed", "0xFF5252")
    SetTimer(() => SetStatus("Ready"), -3000)
}


SetStatus(msg, dotCol := "0x4CAF50") {
    StatusTxt.Value := msg
    StatusDot.SetFont("c" dotCol)
}


MonitorRoblox() {
    global RobloxPID
    pid := ProcessExist("RobloxPlayerBeta.exe")
    if (pid && pid != RobloxPID) {
        RobloxPID := pid
        if (ahhfuck.Attach(pid)) {
            SetStatus("Roblox attached  (PID " pid ")", "0x4CAF50")
            AddLog("System", "RobloxPlayerBeta.exe", "Attached  PID=" pid)
            if (AutoApplyCB.Value) {
                if (UseSingleton.Value && FileExist(SingletonExe))
                    try Run(SingletonExe)
                SetTimer(() => ApplyFlagsToRoblox(true), -4000)
            }
        }
    } else if (!pid && RobloxPID) {
        RobloxPID := 0
        SetStatus("Waiting for Roblox...", "0x6A6A84")
        AddLog("System", "RobloxPlayerBeta.exe", "Process closed")
    }
}


FetchOffsets() {
    global PrefixMap, AllOffsets, AllPresetFlags
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        
        whr.Open("GET", "https://raw.githubusercontent.com/AE12IA/fflag-offsets/main/prefixes.json", true)
        whr.Send()
        whr.WaitForResponse()
        if (whr.Status == 200) {
            pText := whr.ResponseText
            pos := 1
            while (pos := RegExMatch(pText, '"(?P<Full>[^"]+)":', &m, pos)) {
                full := m["Full"]
                clean := RegExReplace(full, "^(FFlag|FInt|FString|FLog|DFFlag|DFInt|DFString|DFLog|SFInt|SFString|SFFlag|Int)")
                PrefixMap[clean] := full
                pos += m.Len
            }
        }

        versionBranch := GetCurrentRobloxVersionBranch()
	if (versionBranch = "") 
	{
    		SetStatus("Roblox version folder not found in AppData\Local\Roblox\Versions", "0xFF5252")
    		AddLog("System", "GetVersion", "No version-* folder with RobloxPlayerBeta.exe found")
    		return
	}

	offsetsUrl := "https://raw.githubusercontent.com/AE12IA/fflag-offsets/" versionBranch "/offsets.hpp"
        whr.Open("GET", offsetsUrl, true)
        whr.Send()
        whr.WaitForResponse()
        if RegExMatch(whr.ResponseText, "s)namespace FFlags\s*\{([^}]+)\}", &match) {
            content := match[1]
            pos     := 1
            AllOffsets := Map()
            AllPresetFlags := []
            while (pos := RegExMatch(content, "uintptr_t\s+(\w+)\s*=\s*(0x[0-9A-Fa-f]+);", &m, pos)) {
                AllOffsets[m[1]] := Integer(m[2])
                AllPresetFlags.Push(m[1])
                pos += m.Len
            }
        }
        SetStatus("Offsets ready (" AllPresetFlags.Length " flags) [" versionBranch "]", "0x4CAF50")
        AddLog("System", "FetchOffsets", "Loaded " AllPresetFlags.Length " from " versionBranch)
        SetTimer(() => SetStatus("Ready"), -3000)
    } catch as e {
        SetStatus("Failed to load offsets!", "0xFF5252")
        AddLog("System", "FetchOffsets", "ERROR: " e.Message)
    }
}


GetPrefixedName(name) {
    global PrefixMap
    return PrefixMap.Has(name) ? PrefixMap[name] : name
}

SaveSettings() {
    s := '{"UseSingleton":' (UseSingleton.Value ? "true" : "false") 
       . ',"AutoApply":' (AutoApplyCB.Value ? "true" : "false")
       . ',"ReApply":' (ReApplyCB.Value ? "true" : "false") '}'
    try FileOpen(SettingsFile, "w", "UTF-8").Write(s)
}

LoadSettings() {
    if (!FileExist(SettingsFile))
        return
    try {
        c := FileRead(SettingsFile)
        if RegExMatch(c, '"UseSingleton":\s*(true|false)', &m1)
            UseSingleton.Value := (m1[1] = "true")
        if RegExMatch(c, '"AutoApply":\s*(true|false)', &m2)
            AutoApplyCB.Value := (m2[1] = "true")
        if RegExMatch(c, '"ReApply":\s*(true|false)', &m3)
            ReApplyCB.Value := (m3[1] = "true")
        
        ManageReApplyTimer()
    }
}

InferType(v) {
    v := StrLower(Trim(String(v)))
    if (v = "true" || v = "false")
        return "bool"
    return IsNumber(v) ? (InStr(v, ".") ? "float" : "int") : "string"
}

SaveUserFlags() {
    s := "["
    for f in UserFlags
        s .= '{"name":"' f["name"] '","value":"' f["value"] '","type":"' f["type"] '"},'
    s := RTrim(s, ",") "]"
    try FileOpen(UserFlagsFile, "w", "UTF-8").Write(s)
}

LoadUserFlags() {
    if (!FileExist(UserFlagsFile))
        return
    try {
        c   := FileRead(UserFlagsFile)
        pos := 1
        while (pos := RegExMatch(c, '\{"name":"([^"]+)","value":"([^"]*)","type":"([^"]+)"\}', &m, pos)) {
            UserFlags.Push(Map("name", m[1], "value", m[2], "type", m[3]))
            pos += m.Len
        }
        RefreshMainList()
    }
}

ManageReApplyTimer() {
    if (ReApplyCB.Value) {
        SetTimer(ExecuteReApplyBatches, 2000)
    } else {
        SetTimer(ExecuteReApplyBatches, 0)
    }
}

ExecuteReApplyBatches() {
    global RobloxPID, UserFlags, ahhfuck, UseSingleton, AllOffsets

    if (!RobloxPID || UserFlags.Length == 0 || !ahhfuck.hProcess)
        return

    restored := 0

    for flag in UserFlags {
        name  := flag["name"]
        desired := flag["value"]
        ftype := flag["type"] ? flag["type"] : InferType(desired)


        current := ""
        addr := 0
        vp := 0 

        if (UseSingleton.Value) {
            sgl := ahhfuck.GetSingleton()
            if (!sgl)
                continue

            hash := 0xcbf29ce484222325
            Loop Parse, name {
                hash := hash ^ Ord(A_LoopField)
                hash := Integer(hash * 0x100000001b3)
            }

            m_list := ahhfuck.ReadUInt64(sgl + 24)
            m_mask := ahhfuck.ReadUInt64(sgl + 48)
            if (!m_list || !m_mask)
                continue

            bucket := hash & m_mask
            node   := ahhfuck.ReadUInt64(m_list + (bucket * 16) + 8)

            found := false
            loop 300 {  
                if (!node)
                    break
                entry := ahhfuck.ReadMemory(node, 64)
                if (!entry)
                    break

                str_sz  := NumGet(entry, 32, "Int64")
                str_alc := NumGet(entry, 40, "Int64")
                ename   := (str_alc > 15)
                    ? ahhfuck.ReadString(NumGet(entry, 16, "Int64"), str_sz)
                    : StrGet(entry.ptr + 16, str_sz, "UTF-8")

                if (ename == name) {
                    vpr := NumGet(entry, 48, "Int64")
                    if (vpr) {
                        vp := ahhfuck.ReadUInt64(vpr + 0xC0)
                        if (vp && (ftype = "bool" || ftype = "int")) {
                            current := ahhfuck.ReadInt32(vp)
                        }
                    }
                    found := true
                    break
                }
                node := NumGet(entry, 8, "Int64")
            }

            if (!found)
                continue
        } else if (AllOffsets.Has(name)) {
            addr := ahhfuck.moduleBase + AllOffsets[name]
            if (ftype = "bool" || ftype = "int") {
                current := ahhfuck.ReadInt32(addr)
            }
        }


        desired_num := ""
        if (ftype = "bool") {
            v := StrLower(Trim(String(desired)))
            desired_num := (v = "true" || v = "1") ? 1 : 0
        } else if (ftype = "int") {
            v := Trim(String(desired))
            if IsInteger(v) {
                desired_num := Integer(v)
            }
        }


        if (desired_num != "" && current != "" && current = desired_num)
            continue


        success := false
        if (UseSingleton.Value) {
            success := ahhfuck.SetFlag(name, desired)
        } else if (addr) {
            success := WriteRawMemory(addr, desired, ftype)
        }

        if (success) {
            restored++
            AddLog("ReApply", name, "Restored")
        }
    }

    if (restored > 0) {
        AddLog("ReApply", "Summary", "Restored " restored " FFlags")
        SetStatus("Re-Apply Restored " restored " FFlags", "0xFF9800")
        SetTimer(() => SetStatus("Ready"), -4000)
    }
}

#HotIf WinActive("ahk_id " MyGui.Hwnd)
^c:: {
    if (ControlGetFocus(MyGui.Hwnd) == MainList.Hwnd) {
        selectedData := "{"
        row := 0
        count := 0
        loop {
            row := MainList.GetNext(row)
            if (!row) {
                break
            }
            
            name  := MainList.GetText(row, 2)
            val   := MainList.GetText(row, 4)
            pName := GetPrefixedName(name)
            
            selectedData .= "`n    `"" pName "`": `"" val "`","
            count++
        }
        
        if (count > 0) {
            selectedData := RTrim(selectedData, ",") "`n}"
            A_Clipboard := selectedData
            SetStatus("Copied " count " flags to clipboard", "0x2979FF")
            SetTimer(() => SetStatus("Ready"), -2000)
        }
    }
}
#HotIf

SetTimer(MonitorRoblox, 500)
SetTimer(FetchOffsets, -100)
LoadUserFlags()
LoadSettings()
SwitchView("Main")



SetTimerResolution(resolution := 5000) {
    static current := 0
    DllCall("ntdll\ZwSetTimerResolution"
        , "Int", resolution
        , "Int", 1
        , "Int*", current)
}

Insert::
{
    global IsGuiHidden
    
    if (IsGuiHidden)
    {
        MyGui.Show()
        WinActivate "ahk_id " MyGui.Hwnd
        IsGuiHidden := false
    }
    else
    {
        MyGui.Hide()
        IsGuiHidden := true
    }
    return
}


OnExit(Shutdown)

Shutdown(*) {
    DllCall("ntdll\ZwSetTimerResolution"
        , "Int", 5000
        , "Int", 0
        , "Int*", 0)
}

GetCurrentRobloxVersionBranch() {
    versionDir := EnvGet("LOCALAPPDATA") "\Roblox\Versions"
    chosen := ""
    newest := ""

    Loop Files, versionDir "\version-*", "D" {
        exe := A_LoopFileFullPath "\RobloxPlayerBeta.exe"
        if !FileExist(exe)
            continue

        t := A_LoopFileTimeModified
        if (newest = "" || t > newest) {
            newest := t
            chosen := A_LoopFileName
        }
    }

    return chosen 
}
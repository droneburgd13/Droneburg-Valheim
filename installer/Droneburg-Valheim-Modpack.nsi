Unicode True

!include "MUI2.nsh"

Name "Droneburg Valheim Modpack"
OutFile "../../../packages/Droneburg-Valheim-Modpack-v1.1.0.exe"

InstallDir "$PROGRAMFILES64\Steam\steamapps\common\Valheim"

RequestExecutionLevel admin

SetCompressor /SOLID lzma
ShowInstDetails show

Var BackupBase
Var BackupDir

!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\orange-install.ico"

!define MUI_WELCOMEPAGE_TITLE "Droneburg Valheim Modpack"
!define MUI_WELCOMEPAGE_TEXT "This installer will configure Valheim for the Droneburg server.$\r$\n$\r$\nIt installs BepInEx and the exact mod versions required by the server.$\r$\n$\r$\nPlease close Valheim before continuing."

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_TITLE "Droneburg is ready."
!define MUI_FINISHPAGE_TEXT "The Droneburg Valheim modpack has been installed.$\r$\n$\r$\nLaunch Valheim normally through Steam."
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "English"


Function .onInit

    ; Try Steam's registered Valheim installation first.

    SetRegView 64
    ReadRegStr $INSTDIR HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 892970" \
        "InstallLocation"
    IfFileExists "$INSTDIR\valheim.exe" found

    SetRegView 32
    ReadRegStr $INSTDIR HKLM \
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 892970" \
        "InstallLocation"
    IfFileExists "$INSTDIR\valheim.exe" found

    ; Try the current user's primary Steam library.

    ReadRegStr $0 HKCU "Software\Valve\Steam" "SteamPath"
    StrCmp $0 "" scan_drives

    StrCpy $INSTDIR "$0\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

scan_drives:

    ; Scan common Steam library layouts across C: through Z:.

    StrCpy $INSTDIR "C:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "C:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "C:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "D:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "D:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "D:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "E:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "E:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "E:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "F:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "F:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "F:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "G:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "G:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "G:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "H:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "H:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "H:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "I:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "I:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "I:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "J:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "J:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "J:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "K:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "K:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "K:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "L:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "L:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "L:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "M:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "M:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "M:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "N:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "N:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "N:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "O:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "O:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "O:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "P:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "P:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "P:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "Q:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "Q:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "Q:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "R:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "R:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "R:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "S:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "S:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "S:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "T:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "T:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "T:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "U:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "U:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "U:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "V:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "V:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "V:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "W:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "W:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "W:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "X:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "X:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "X:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "Y:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "Y:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "Y:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "Z:\SteamLibrary\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "Z:\Steam\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found

    StrCpy $INSTDIR "Z:\steamapps\common\Valheim"
    IfFileExists "$INSTDIR\valheim.exe" found


    ; Automatic detection failed.
    ; Directory page still allows manual browsing.

    StrCpy $INSTDIR "$PROGRAMFILES64\Steam\steamapps\common\Valheim"
    Return

found:

FunctionEnd


Section "Droneburg Valheim Modpack" SecMain

    ; Safety check. We will not write anywhere unless this looks
    ; like an actual Valheim installation.
    IfFileExists "$INSTDIR\valheim.exe" valheim_found

    MessageBox MB_ICONSTOP|MB_OK \
        "valheim.exe was not found in:$\r$\n$\r$\n$INSTDIR$\r$\n$\r$\nSelect your Valheim installation folder and run the installer again."

    Abort

valheim_found:

    DetailPrint "Valheim found:"
    DetailPrint "$INSTDIR"

    ; Pick an unused backup directory.
    StrCpy $BackupBase "$INSTDIR\Droneburg-Modpack-Backup"
    StrCpy $BackupDir "$BackupBase"
    StrCpy $0 1

backup_check:

    IfFileExists "$BackupDir\*.*" backup_exists backup_ready

backup_exists:

    StrCpy $BackupDir "$BackupBase-$0"
    IntOp $0 $0 + 1
    Goto backup_check

backup_ready:

    CreateDirectory "$BackupDir"

    DetailPrint "Backup directory:"
    DetailPrint "$BackupDir"

    ; Preserve any existing mod-loader installation.
    IfFileExists "$INSTDIR\BepInEx\*.*" 0 +3
        DetailPrint "Backing up existing BepInEx..."
        Rename "$INSTDIR\BepInEx" "$BackupDir\BepInEx"

    IfFileExists "$INSTDIR\winhttp.dll" 0 +3
        DetailPrint "Backing up existing winhttp.dll..."
        Rename "$INSTDIR\winhttp.dll" "$BackupDir\winhttp.dll"

    IfFileExists "$INSTDIR\doorstop_config.ini" 0 +3
        DetailPrint "Backing up existing doorstop_config.ini..."
        Rename "$INSTDIR\doorstop_config.ini" "$BackupDir\doorstop_config.ini"

    IfFileExists "$INSTDIR\doorstop_libs\*.*" 0 +3
        DetailPrint "Backing up existing doorstop libraries..."
        Rename "$INSTDIR\doorstop_libs" "$BackupDir\doorstop_libs"

    IfFileExists "$INSTDIR\.doorstop_version" 0 +3
        DetailPrint "Backing up existing doorstop version..."
        Rename "$INSTDIR\.doorstop_version" "$BackupDir\.doorstop_version"

    IfFileExists "$INSTDIR\start_game_bepinex.sh" 0 +2
        Rename "$INSTDIR\start_game_bepinex.sh" "$BackupDir\start_game_bepinex.sh"

    IfFileExists "$INSTDIR\start_server_bepinex.sh" 0 +2
        Rename "$INSTDIR\start_server_bepinex.sh" "$BackupDir\start_server_bepinex.sh"

    IfFileExists "$INSTDIR\DRONEBURG-MODPACK.txt" 0 +2
        Rename "$INSTDIR\DRONEBURG-MODPACK.txt" "$BackupDir\DRONEBURG-MODPACK.txt"

    ; Deploy the known-good package.
    SetOutPath "$INSTDIR"

    File /r "payload\*"

    DetailPrint ""
    DetailPrint "Droneburg Valheim Modpack v1.1.0 installed."
    DetailPrint "Installation directory: $INSTDIR"
    DetailPrint "Previous mod files, if present, are in: $BackupDir"

SectionEnd

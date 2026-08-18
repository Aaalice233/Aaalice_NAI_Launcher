!include "MUI2.nsh"
!include "LogicLib.nsh"

!ifndef VERSION
  !define VERSION "0.0.0"
!endif

!ifndef SOURCE_DIR
  !define SOURCE_DIR "..\..\build\windows\x64\runner\Release"
!endif

!ifndef OUT_FILE
  !define OUT_FILE "NAI_Launcher_Windows_Setup.exe"
!endif

!ifndef APP_NAME
  !define APP_NAME "Aaalice NAI Launcher"
!endif

!ifndef APP_EXE
  !define APP_EXE "nai_launcher.exe"
!endif

!ifndef PUBLISHER
  !define PUBLISHER "Aaalice"
!endif

!ifndef UNINSTALL_KEY
  !define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Aaalice NAI Launcher"
!endif

Name "${APP_NAME}"
OutFile "${OUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\Aaalice NAI Launcher"
InstallDirRegKey HKCU "${UNINSTALL_KEY}" "InstallLocation"
RequestExecutionLevel user
SetCompressor /SOLID lzma
Unicode true

!define /math PROCESS_PATH_BUFFER_BYTES ${NSIS_MAX_STRLEN} * 2

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"

LangString AppRunningPrompt ${LANG_SIMPCHINESE} "检测到 ${APP_NAME} 仍在运行（关闭窗口可能只是缩到托盘）。安装程序将关闭应用后继续，是否现在关闭？"
LangString AppRunningPrompt ${LANG_ENGLISH} "${APP_NAME} is still running (closing its window may only hide it to the tray). Close it and continue setup?"
LangString AppCloseFailed ${LANG_SIMPCHINESE} "无法关闭正在运行的 ${APP_NAME}。请从系统托盘退出应用后重试。"
LangString AppCloseFailed ${LANG_ENGLISH} "Unable to close ${APP_NAME}. Exit it from the system tray and try again."

Var TargetProcessId

!macro DefineProcessFunctions Prefix
Function ${Prefix}FindInstalledAppProcess
  Push $R0
  Push $R1
  Push $R2
  Push $R3
  Push $R4
  Push $R5
  Push $R6
  Push $R7
  Push $R8
  Push $R9

  StrCpy $TargetProcessId "0"
  ClearErrors
  GetFullPathName $R9 "$INSTDIR\${APP_EXE}"
  IfErrors find_process_done

  System::Alloc 65536
  Pop $R0
  StrCpy $R1 $R0
  System::Call 'kernel32::K32EnumProcesses(p R0, i 65536, *i .R2) i .R3'
  StrCmp $R3 "0" find_process_cleanup
  IntOp $R2 $R2 / 4
  StrCpy $R3 "0"

find_process_loop:
  IntCmp $R3 $R2 find_process_cleanup
  System::Call '*$R1(i .R4)'
  StrCmp $R4 "0" find_process_next
  System::Call 'kernel32::OpenProcess(i 0x00001000, i 0, i R4) p .R5'
  StrCmp $R5 "0" find_process_next
  System::Alloc ${PROCESS_PATH_BUFFER_BYTES}
  Pop $R6
  StrCpy $R7 ${NSIS_MAX_STRLEN}
  System::Call 'kernel32::QueryFullProcessImageNameW(p R5, i 0, p R6, *i R7) i .R8'
  System::Call 'kernel32::CloseHandle(p R5)'
  StrCmp $R8 "0" find_process_free_path
  System::Call '*$R6(&w${NSIS_MAX_STRLEN} .R7)'
  System::Call 'kernel32::lstrcmpiW(w R7, w R9) i .R8'
  StrCmp $R8 "0" find_process_found

find_process_free_path:
  System::Free $R6

find_process_next:
  IntOp $R1 $R1 + 4
  IntOp $R3 $R3 + 1
  Goto find_process_loop

find_process_found:
  System::Free $R6
  StrCpy $TargetProcessId $R4

find_process_cleanup:
  System::Free $R0

find_process_done:
  Pop $R9
  Pop $R8
  Pop $R7
  Pop $R6
  Pop $R5
  Pop $R4
  Pop $R3
  Pop $R2
  Pop $R1
  Pop $R0
FunctionEnd

Function ${Prefix}EnsureAppClosed
  Call ${Prefix}FindInstalledAppProcess
  StrCmp $TargetProcessId "0" app_closed

  IfSilent close_app 0
  MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL "$(AppRunningPrompt)" IDOK close_app IDCANCEL cancel_install

close_app:
  nsExec::ExecToLog '"$SYSDIR\taskkill.exe" /PID $TargetProcessId /T /F'
  Sleep 1000
  Call ${Prefix}FindInstalledAppProcess
  StrCmp $TargetProcessId "0" app_closed

  IfSilent silent_close_failed 0
  MessageBox MB_ICONSTOP|MB_OK "$(AppCloseFailed)"
  Abort

silent_close_failed:
  SetErrorLevel 2
  Quit

cancel_install:
  Abort

app_closed:
FunctionEnd
!macroend

!insertmacro DefineProcessFunctions ""
!insertmacro DefineProcessFunctions "un."

Section "${APP_NAME}" SecMain
  SectionIn RO

  Call EnsureAppClosed
  SetOverwrite on
  SetOutPath "$INSTDIR"
  File /r "${SOURCE_DIR}\*.*"

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk" "$INSTDIR\Uninstall.exe"

  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXE}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

Section "Desktop Shortcut" SecDesktop
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
SectionEnd

Section "Uninstall"
  Call un.EnsureAppClosed

  Delete "$DESKTOP\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"

  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  RMDir /r "$INSTDIR"
SectionEnd

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "StrFunc.nsh"

${StrStr}

!ifndef VERSION
  !define VERSION "0.0.0"
!endif

!ifndef SOURCE_DIR
  !define SOURCE_DIR "..\..\build\windows\x64\runner\Release"
!endif

!ifndef OUT_FILE
  !define OUT_FILE "NAI_Launcher_Windows_Setup.exe"
!endif

!define APP_NAME "Aaalice NAI Launcher"
!define APP_EXE "nai_launcher.exe"
!define PUBLISHER "Aaalice"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Aaalice NAI Launcher"

Name "${APP_NAME}"
OutFile "${OUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\Aaalice NAI Launcher"
InstallDirRegKey HKCU "${UNINSTALL_KEY}" "InstallLocation"
RequestExecutionLevel user
SetCompressor /SOLID lzma
Unicode true

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

Function CheckAppRunning
  nsExec::ExecToStack '"$SYSDIR\tasklist.exe" /FI "IMAGENAME eq ${APP_EXE}" /NH'
  Pop $R0
  Pop $R1
  ${StrStr} $R2 $R1 "${APP_EXE}"
  StrCmp $R2 "" 0 app_is_running
  Push "0"
  Return

app_is_running:
  Push "1"
FunctionEnd

Function EnsureAppClosed
  Call CheckAppRunning
  Pop $R0
  StrCmp $R0 "0" app_closed

  IfSilent close_app 0
  MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL "$(AppRunningPrompt)" IDOK close_app IDCANCEL cancel_install

close_app:
  nsExec::ExecToLog '"$SYSDIR\taskkill.exe" /IM ${APP_EXE} /T /F'
  Sleep 1000
  Call CheckAppRunning
  Pop $R0
  StrCmp $R0 "0" app_closed

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
  nsExec::ExecToLog 'taskkill /IM ${APP_EXE} /F'

  Delete "$DESKTOP\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"

  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  RMDir /r "$INSTDIR"
SectionEnd

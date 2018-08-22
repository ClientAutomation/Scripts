@echo off
setlocal enableextensions enabledelayedexpansion
echo.
echo *******************************************************
echo **     Client Auto (ITCM) Agent Uninstall Script     **
echo *******************************************************

:Usage
if "%1"=="?" set res=T
if "%1"=="-?" set res=T
if "%1"=="/?" set res=T
if "%res%"=="T" (
  echo.
  echo Usage: ITCM-Uninstall [-lite]
  echo.
  echo -lite : optional.
  echo   DO NOT remove entire ComputerAssociates registry key.
  echo   DO NOT remove entire CA folder.
  echo.
  echo   Default behavior (without -lite^^^) will attempt to
  echo   remove CA folder and ComputerAssociates registry key.
  echo.)
if "%1"=="?" exit /b 0
if "%1"=="-?" exit /b 0
if "%1"=="/?" exit /b 0


:ParentCheck
TITLE itcm-uninstall
for /F "tokens=2 delims=," %%a in ('tasklist /V /FO csv ^|find "cmd.exe" ^|find "itcm-uninstall"') do set MYPID=%%a
set MYPID=%MYPID:"=%
for /F "tokens=2 delims==" %%a in ('wmic process where "processid=%MYPID%" get parentprocessid /format:list') do set PPID=%%a
for /F "tokens=1" %%a in ('tasklist /FI "PID eq %PPID%" /NH') do set PPNAME=%%a
if "%PPNAME%"=="sd_jexec.exe" (
  echo Running under software delivery.
  echo Copy File: "%cd%\%~nx0"
  echo        To: "%windir%\temp\%~nx0"
  copy /y "%cd%\%~nx0" "%windir%\temp\%~nx0"
  echo Starting detached process and exiting...
  start "" "%windir%\temp\%~nx0"
  timeout /T 1
  taskkill /f /im ui0detect.exe 2>nul
  exit /b 0)
if "%PPNAME%"=="INFO:" timeout /T 20


:Settings
set ITCM_LITE_UNINSTALL=0


:CheckParameters
echo.
if "%1"=="lite" set ITCM_LITE_UNINSTALL=1
if "%1"=="LITE" set ITCM_LITE_UNINSTALL=1
if "%1"=="-lite" set ITCM_LITE_UNINSTALL=1
if "%1"=="-LITE" set ITCM_LITE_UNINSTALL=1
if "%ITCM_LITE_UNINSTALL%"=="1" (
  echo Perform lite uninstall.
) else (
  echo Perform FULL uninstall.)

  
:start
set reg_key_name=
set reg_value_name=
set reg_name=
set reg_type=
set reg_value=
set dsm_bin=


:check32
echo.
echo Check for ITRM registry key.
set reg_key_name=hkey_local_machine\software\computerassociates\unicenter itrm
set reg_value_name=installdirproduct
for /f "skip=2 tokens=1,2*" %%a in ('reg query "%reg_key_name%" /v "%reg_value_name%" 2^>nul') do (
    set reg_name=%%a
    set reg_type=%%b
    set reg_value=%%c
)
set dsm_bin=%reg_value%bin
if "%dsm_bin%"=="bin" goto check64
echo DSM directory: %dsm_bin%
goto dowork


:check64
echo Check for ITRM registry key [Wow6432Node].

set reg_key_name=
set reg_value_name=
set reg_name=
set reg_type=
set reg_value=
set dsm_bin=

set reg_key_name=hkey_local_machine\software\wow6432node\computerassociates\unicenter itrm
set reg_value_name=installdirproduct
for /f "skip=2 tokens=1,2*" %%a in ('reg query "%reg_key_name%" /v "%reg_value_name%" 2^>nul') do (
    set reg_name=%%a
    set reg_type=%%b
    set reg_value=%%c
)
set dsm_bin=%reg_value%bin

if "%dsm_bin%"=="bin" (
  echo ITRM registry key not found.
  goto notfound
) else (
  echo DSM directory: "%dsm_bin%")
goto dowork


:notfound
echo.
echo No changes have been made.
echo Finished^^!
endlocal
exit /b 0


:dowork
echo.
echo Disable and kill processes...
sc config caf start= disabled >nul 2>nul
sc config hmagent start= disabled >nul 2>nul
sc config caspliteagent start= disabled >nul 2>nul
taskkill /f /im egc30n.exe 2>nul
taskkill /f /im amagentsvc.exe 2>nul
taskkill /f /im sd_jexec.exe 2>nul
taskkill /f /im cfbasichwwnt.exe 2>nul
if "%dsm_bin%"=="bin" (
  caf.exe kill all 2>nul
) else (
  "%dsm_bin%\caf.exe" kill all 2>nul)
taskkill /f /im hmagent.exe 2>nul
taskkill /f /im cfsystray.exe 2>nul
del "%dsm_bin%\cfsystray.exe" /F /Q 2>nul
taskkill /f /im casplitegent.exe 2>nul
taskkill /f /im RtaAgent.exe 2>nul
taskkill /f /im dm_primer.exe 2>nul

if "%ITCM_LITE_UNINSTALL%"=="0" (
  sc config CA-MessageQueuing start= disabled >nul 2>nul
  sc config CA-SAM-Pmux start= disabled >nul 2>nul
  taskkill /f /im cam.exe 2>nul
  taskkill /f /im csampmux.exe 2>nul)

echo.
echo Remove Documentation.
msiexec.exe /x {A56A74D1-E994-4447-A2C7-678C62457FA5} /l*v %temp%\rmDocumentation.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A56A74D1-E994-4447-A2C7-678C62457FA5}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{A56A74D1-E994-4447-A2C7-678C62457FA5}" /f >nul 2>nul

echo.
echo Remove Manager.
msiexec.exe /x {E981CCC3-7C44-4D04-BD38-C7A501469B37} /l*v %temp%\rmManager.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{E981CCC3-7C44-4D04-BD38-C7A501469B37}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{E981CCC3-7C44-4D04-BD38-C7A501469B37}" /f >nul 2>nul

echo Remove Explorer.
msiexec.exe /x {42C0EC64-A6E7-4FBD-A5B6-1A6AD94A2D87} /l*v %temp%\rmExplorer.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{42C0EC64-A6E7-4FBD-A5B6-1A6AD94A2D87}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{42C0EC64-A6E7-4FBD-A5B6-1A6AD94A2D87}" /f >nul 2>nul

echo Remove Scalability Server.
msiexec.exe /x {9654079C-BA1E-4628-8403-C7272FF1BD3E} /l*v %temp%\rmScalability.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{9654079C-BA1E-4628-8403-C7272FF1BD3E}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{9654079C-BA1E-4628-8403-C7272FF1BD3E}" /f >nul 2>nul

echo Remove Agent language package DEU.
msiexec.exe /x {6B511A0E-4D3C-4128-91BE-77740420FD36} /l*v %temp%\rmLangDEU.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{6B511A0E-4D3C-4128-91BE-77740420FD36}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{6B511A0E-4D3C-4128-91BE-77740420FD36}" /f >nul 2>nul

echo Remove Agent language package FRA.
msiexec.exe /x {9DA41BF7-B1B1-46FD-9525-DEDCCACFE816} /l*v %temp%\rmLangFRA.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{9DA41BF7-B1B1-46FD-9525-DEDCCACFE816}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{9DA41BF7-B1B1-46FD-9525-DEDCCACFE816}" /f >nul 2>nul

echo Remove Agent language package JPN.
msiexec.exe /x {A4DA5EED-B13B-4A5E-A8A1-748DE46A2607} /l*v %temp%\rmLangJPN.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A4DA5EED-B13B-4A5E-A8A1-748DE46A2607}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{A4DA5EED-B13B-4A5E-A8A1-748DE46A2607}" /f >nul 2>nul

echo Remove Agent language package ESN.
msiexec.exe /x {94163038-B65E-45BE-A70C-DC319C43CFF2} /l*v %temp%\rmLangESN.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{94163038-B65E-45BE-A70C-DC319C43CFF2}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{94163038-B65E-45BE-A70C-DC319C43CFF2}" /f >nul 2>nul

echo Remove Agent language package KOR.
msiexec.exe /x {2C300042-2857-4E6B-BC05-920CA9953D2C} /l*v %temp%\rmLangKOR.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{2C300042-2857-4E6B-BC05-920CA9953D2C}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{2C300042-2857-4E6B-BC05-920CA9953D2C}" /f >nul 2>nul

echo Remove Agent language package CHS.
msiexec.exe /x {2D3B15F5-BBA3-4D9E-B7AB-DC2A8BD6EAD8} /l*v %temp%\rmLangCHS.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{2D3B15F5-BBA3-4D9E-B7AB-DC2A8BD6EAD8}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{2D3B15F5-BBA3-4D9E-B7AB-DC2A8BD6EAD8}" /f >nul 2>nul

echo Remove CA Asset Management Performance LiteAgent.
msiexec.exe /x {B6588B4E-CF7C-4FF7-AC15-62A8FFD2A506} /l*v %temp%\rmPerfLiteClient.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{B6588B4E-CF7C-4FF7-AC15-62A8FFD2A506}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{B6588B4E-CF7C-4FF7-AC15-62A8FFD2A506}" /f >nul 2>nul

echo Remove CA Systems Performance LiteAgent.
msiexec.exe /x {019094B6-40C9-45AE-A799-CCA2D6AA66A6} /l*v %temp%\rmPerfLiteAgent.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{019094B6-40C9-45AE-A799-CCA2D6AA66A6}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{019094B6-40C9-45AE-A799-CCA2D6AA66A6}" /f >nul 2>nul

echo Remove Remote Control Agent (ENU and multi-language).
msiexec.exe /x {84288555-A79E-4ABD-BA53-219C4D2CA20B} /l*v %temp%\rmRC_Agent.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{84288555-A79E-4ABD-BA53-219C4D2CA20B}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{84288555-A79E-4ABD-BA53-219C4D2CA20B}" /f >nul 2>nul

echo Remove Data Transport Service Agent (ENU and multi-language).
msiexec.exe /x {C0C44BF2-E5E0-4C02-B9D3-33C691F060EA} /l*v %temp%\rmDTS_Agent.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{C0C44BF2-E5E0-4C02-B9D3-33C691F060EA}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{C0C44BF2-E5E0-4C02-B9D3-33C691F060EA}" /f >nul 2>nul

echo Remove Software Delivery Agent (ENU and multi-language).
msiexec.exe /x {62ADA55C-1B98-431F-8618-CDF3CE4CFEEC} /l*v %temp%\rmSD_Agent.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{62ADA55C-1B98-431F-8618-CDF3CE4CFEEC}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{62ADA55C-1B98-431F-8618-CDF3CE4CFEEC}" /f >nul 2>nul

echo Remove Asset Management Agent (ENU and multi-language).
msiexec.exe /x {624FA386-3A39-4EBF-9CB9-C2B484D78B29} /l*v %temp%\rmAM_Agent.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{624FA386-3A39-4EBF-9CB9-C2B484D78B29}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{624FA386-3A39-4EBF-9CB9-C2B484D78B29}" /f >nul 2>nul

echo Remove Basic Inventory Agent (ENU and multi-language).
msiexec.exe /x {501C99B9-1644-4FC2-833B-E675572F8929} /l*v %temp%\rmBH_Agent.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{501C99B9-1644-4FC2-833B-E675572F8929}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{501C99B9-1644-4FC2-833B-E675572F8929}" /f >nul 2>nul

echo Remove DMPrimer.
msiexec.exe /x {5933cc13-52ab-4713-85db-e72034b5697A} /l*v %temp%\rmOldDMPrimer.log /qn 
msiexec.exe /x {A312C331-2E7A-42E1-9F31-902920C402EE} /l*v %temp%\rmDMPrimer.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{5933cc13-52ab-4713-85db-e72034b5697A}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{5933cc13-52ab-4713-85db-e72034b5697A}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A312C331-2E7A-42E1-9F31-902920C402EE}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{A312C331-2E7A-42E1-9F31-902920C402EE}" /f >nul 2>nul

if "%ITCM_LITE_UNINSTALL%"=="0" (
  echo Remove CA Secure Socket Adapter.
  msiexec.exe /x {25CCFBFE-BDE1-43F8-B078-C9AC89B21AF2} /l*v %temp%\rmSSA.log /qn
  reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{25CCFBFE-BDE1-43F8-B078-C9AC89B21AF2}" /f >nul 2>nul
  reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{25CCFBFE-BDE1-43F8-B078-C9AC89B21AF2}" /f >nul 2>nul)

echo Remove MasterSetup.
msiexec.exe /x {C163EC47-55B6-4B06-9D03-2A720548BE86} /l*v %temp%\rmOldMasterSetup.log /qn
msiexec.exe /x {DA485AC8-BACB-492D-9B1E-14AA5B61597E} /l*v %temp%\rmMasterSetup.log /qn
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{C163EC47-55B6-4B06-9D03-2A720548BE86}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{C163EC47-55B6-4B06-9D03-2A720548BE86}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\InstallShield_{C163EC47-55B6-4B06-9D03-2A720548BE86}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\InstallShield_{C163EC47-55B6-4B06-9D03-2A720548BE86}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{DA485AC8-BACB-492D-9B1E-14AA5B61597E}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{DA485AC8-BACB-492D-9B1E-14AA5B61597E}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\InstallShield_{DA485AC8-BACB-492D-9B1E-14AA5B61597E}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\InstallShield_{DA485AC8-BACB-492D-9B1E-14AA5B61597E}" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\CA_Client_Automation_r12_5_SP1C1" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\CA_Client_Automation_r12_5_SP1C1" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\CA IT Client Manager 12_9 Feature Pack 1" /f >nul 2>nul
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\CA IT Client Manager 12_9 Feature Pack 1" /f >nul 2>nul

echo Remove CA folder.
if "%ITCM_LITE_UNINSTALL%"=="0" (
  if "%dsm_bin%"=="bin" (
    rd "%SystemDrive%\Program Files\CA" /S /Q 2>nul
    rd "%SystemDrive%\Program Files (x86)\CA" /S /Q 2>nul
  ) else (
    rd "%dsm_bin%\..\..\" /S /Q 2>nul))
if "%ITCM_LITE_UNINSTALL%"=="1" (
  if "%dsm_bin%"=="bin" (
    rd "%SystemDrive%\Program Files\CA\DSM" /S /Q 2>nul
    rd "%SystemDrive%\Program Files (x86)\CA\DSM" /S /Q 2>nul
) else (
  rd "%dsm_bin%\..\" /S /Q 2>nul))

echo.
echo File cleanup.
del "%SystemDrive%\dmmsi.log" /F /Q 2>nul
del "%SystemDrive%\S.log" /F /Q 2>nul

echo.
echo Service cleanup.
if "%ITCM_LITE_UNINSTALL%"=="0" (
  sc delete CA-SAM-Pmux >nul 2>nul
  sc delete CA-MessageQueuing >nul 2>nul)
sc delete caf >nul 2>nul
sc delete hmAgent >nul 2>nul

echo.
echo Cleanup registry.
if "%ITCM_LITE_UNINSTALL%"=="0" (
  reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\ComputerAssociates" /f >nul 2>nul
  reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\ComputerAssociates" /f >nul 2>nul
) else (
  reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\ComputerAssociates\Unicenter ITRM" /f >nul 2>nul
  reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\ComputerAssociates\Unicenter ITRM" /f >nul 2>nul)


:finish
echo.
echo Finished^^!
endlocal
exit
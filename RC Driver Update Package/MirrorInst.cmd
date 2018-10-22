@echo off
setlocal enableextensions enabledelayedexpansion

REM --------------------------------------------
REM Remote Control Mirror Driver Update Script
REM
REM Original Author: 
REM Brian Fontana, Principal Engineer, CA Support
REM
REM Last Updated:
REM 22-Oct 2018 -- Brian Fontana.
REM Change "xcopy" to "copy", which is native to the
REM command interpreter.
REM
REM 27-Sep 2018 -- Brian Fontana.
REM Orignal version.
REM
REM Purpose:
REM This script will check if the RC feature is installed on the system,
REM and if so, install the updated mirror driver, in order to resolve
REM various compatibility issues experienced with Windows 10.
REM
REM Note:
REM The udpated driver drops support for "Secure Control" connection mode.
REM --------------------------------------------

echo.
echo *********************************************
echo **        RC Mirror Driver Install         **
echo *********************************************
echo.

REM Check system architecture (x86 vs x64).
reg query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set arch=32 || set arch=64

REM Read CA Install directory from registry.
set itrm_key_name=HKEY_LOCAL_MACHINE\SOFTWARE\ComputerAssociates\Unicenter ITRM
set itrm_value=InstallDir
for /f "skip=2 tokens=1,2*" %%a in ('reg query "%itrm_key_name%" /v "%itrm_value%" 2^>nul') do (set reg_value=%%c)
set itrm_dir=%reg_value%

REM Not found, check 32-bit registry.
if "%itrm_dir%"=="" (
  set itrm_key_name=HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\ComputerAssociates\Unicenter ITRM
  for /f "skip=2 tokens=1,2*" %%a in ('reg query "!itrm_key_name!" /v "!itrm_value!" 2^>nul') do (set reg_value=%%c)
  set itrm_dir=!reg_value!)

REM Exit code 10 -- ITCM agent is not installed.
if "%itrm_dir%"=="" (
  echo ITCM agent not installed, exiting...
  endlocal
  exit /b 10)

REM Read ITCM agent version.
set itrm_value=InstallVersion
set reg_value=
for /f "skip=2 tokens=1,2*" %%a in ('reg query "%itrm_key_name%" /v "%itrm_value%" 2^>nul') do (set reg_value=%%c)
set itrm_version=%reg_value%
set reg_value=

REM Read ITCM feature list.
if %arch%==32 (
  set itrm_key_name=HKEY_LOCAL_MACHINE\SOFTWARE\ComputerAssociates\Unicenter ITRM\InstalledFeatures
) else (
  set itrm_key_name=HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\ComputerAssociates\Unicenter ITRM\InstalledFeatures)
set itrm_value=Agent - Remote Control
for /f "skip=2 tokens=1,2*" %%a in ('reg query "%itrm_key_name%" /v "%itrm_value%" 2^>nul') do (set reg_value=%%c)
set rc_installed=%reg_value%

REM Exit code 20 -- RC feature is not installed.
if "%rc_installed%"=="" (
  echo Remote control feature not installed, exiting...
  endlocal
  exit /b 20
) else ( 
  set rc_installed=YES)

REM Output summary info.
echo ITCM Install Dir: %itrm_dir%
echo ITCM Version: %itrm_version%
echo RC Installed: %rc_installed%
echo Architecture: %arch%-bit

REM Check driver modified date.
if %arch%==32 (
  set current_file="%itrm_dir%DSM\bin\x86\RCMirrorInstall.exe"
  set patch_file="%~dp0RCMirrorInstall_x86.exe"
  for %%i in (!current_file!) do set current_date=%%~ti
  for %%i in (!patch_file!) do set patch_date=%%~ti
) else (
  set current_file="%itrm_dir%DSM\bin\AMD64\RCMirrorInstall.exe"
  set patch_file="%~dp0RCMirrorInstall.exe"
  for %%i in (!current_file!) do set current_date=%%~ti
  for %%i in (!patch_file!) do set patch_date=%%~ti
)

REM Output dates.
echo Driver date: %current_date%
echo Patch date: %patch_date%

REM Compare modified dates
if "%current_date%"=="%patch_date%" (
  echo.
  echo Driver is already up to date, exiting...
  exit /b 0
) else (
  echo.
  echo Driver requires an update, installing...)

REM Copy new driver and install it.
if %arch%==32 (
  echo From: "%~dp0RCMirrorInstall_x86.exe"
  echo   To: "%itrm_dir%DSM\bin\x86\RCMirrorInstall.exe"
  copy "%~dp0RCMirrorInstall_x86.exe" "%itrm_dir%DSM\bin\x86\RCMirrorInstall.exe" /Y
  "%itrm_dir%DSM\bin\x86\RCMirrorInstall.exe" -install
) else (
  echo From: "%~dp0RCMirrorInstall.exe"
  echo   To: "%itrm_dir%DSM\bin\AMD64\RCMirrorInstall.exe"
  copy "%~dp0RCMirrorInstall.exe" "%itrm_dir%DSM\bin\AMD64\RCMirrorInstall.exe" /Y
  "%itrm_dir%DSM\bin\AMD64\RCMirrorInstall.exe" -install)

REM Exit code 0 -- Successful execution.
endlocal
exit /b 0

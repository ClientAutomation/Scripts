@echo off
setlocal enableextensions enabledelayedexpansion
echo.
echo *********************************************
echo **        RC Mirror Driver Install         **
echo *********************************************
echo.
reg query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set arch=32 || set arch=64
set itrm_key_name=HKEY_LOCAL_MACHINE\SOFTWARE\ComputerAssociates\Unicenter ITRM
set itrm_value=InstallDir
for /f "skip=2 tokens=1,2*" %%a in ('reg query "%itrm_key_name%" /v "%itrm_value%" 2^>nul') do (set reg_value=%%c)
set itrm_dir=%reg_value%
if "%itrm_dir%"=="" (
  set itrm_key_name=HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\ComputerAssociates\Unicenter ITRM
  for /f "skip=2 tokens=1,2*" %%a in ('reg query "!itrm_key_name!" /v "!itrm_value!" 2^>nul') do (set reg_value=%%c)
  set itrm_dir=!reg_value!)
if "%itrm_dir%"=="" (
  echo ITCM agent not installed, exiting...
  endlocal
  exit /b 1)
set itrm_value=InstallVersion
set reg_value=
for /f "skip=2 tokens=1,2*" %%a in ('reg query "%itrm_key_name%" /v "%itrm_value%" 2^>nul') do (set reg_value=%%c)
set itrm_version=%reg_value%
set reg_value=
if %arch%==32 (
  set itrm_key_name=HKEY_LOCAL_MACHINE\SOFTWARE\ComputerAssociates\Unicenter ITRM\InstalledFeatures
) else (
  set itrm_key_name=HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\ComputerAssociates\Unicenter ITRM\InstalledFeatures)
set itrm_value=Agent - Remote Control
for /f "skip=2 tokens=1,2*" %%a in ('reg query "%itrm_key_name%" /v "%itrm_value%" 2^>nul') do (set reg_value=%%c)
set rc_installed=%reg_value%
if "%rc_installed%"=="" (
  echo Remote control feature not installed, exiting...
  endlocal
  exit /b 2
) else ( 
  set rc_installed=YES)
echo ITCM Install Dir: %itrm_dir%
echo ITCM Version: %itrm_version%
echo RC Installed: %rc_installed%
echo Architecture: %arch%-bit
echo Copy new driver:
if %arch%==32 (
  echo From: "%~dp0RCMirrorInstall_x86.exe"
  echo   To: "%itrm_dir%DSM\bin\x86\RCMirrorInstall.exe"
  xcopy "%~dp0RCMirrorInstall_x86.exe" "%itrm_dir%DSM\bin\x86\RCMirrorInstall.exe" /Y
  "%itrm_dir%DSM\bin\x86\RCMirrorInstall.exe" -install
) else (
  echo From: "%~dp0RCMirrorInstall.exe"
  echo   To: "%itrm_dir%DSM\bin\AMD64\RCMirrorInstall.exe"
  xcopy "%~dp0RCMirrorInstall.exe" "%itrm_dir%DSM\bin\AMD64\RCMirrorInstall.exe" /Y
  "%itrm_dir%DSM\bin\AMD64\RCMirrorInstall.exe" -install)
endlocal
exit /b 0
@echo off
setlocal enableextensions enabledelayedexpansion
echo.
echo *********************************************
echo **        ITCM Agent Install Script        **
echo *********************************************


:Usage
echo.
echo Usage: ITCM-Agent-Install [Scalability Server]
echo.
echo [Scalability Server] -- optional.
echo   The FQDN or IP of the scalability server the
echo   ITCM agent should register. Specify without
echo   the square brackets.
if "%1"=="?" exit /b 0
if "%1"=="-?" exit /b 0
if "%1"=="/?" exit /b 0


:Settings
REM This is the default scalability server the ITCM agent will register with.
REM Note: This value is overridden by %1, if passed to the script.
set DEFAULT_SCALABILITY_SERVER=fonbr01-u177231.ca.com

REM This is the sub-folder, relative to this script, that contains the itcm agent installation files.
set ITCM_SOURCE_FILES=Windows_x86


:Validations
echo.
echo Configured Settings:
echo --------------------
echo Default Scalability Server: %DEFAULT_SCALABILITY_SERVER%
echo Client Auto Source Files:   %cd%\%ITCM_SOURCE_FILES%
if "%DEFAULT_SCALABILITY_SERVER%"=="" (
  echo Missing default scalability server setting!
  goto ValidationsFail)
if not exist "%cd%\%ITCM_SOURCE_FILES%" (
  echo ITCM installation files not found at configured path!
  goto ValidationsFail)
goto CheckParameters


:ValidationsFail
echo.
echo ********************************************
echo Agent install script DID NOT complete successfully.
echo Failed to validate script configuration settings.
echo Please review each setting at the top of the script.
echo ********************************************
endlocal
exit /b 1


:CheckParameters
echo.
echo Checking parameters..
echo ---------------------
if "%1"=="" (
  echo Using default scalability server: %DEFAULT_SCALABILITY_SERVER%
) else (
  echo Using scalability server: %1
  set DEFAULT_SCALABILITY_SERVER=%1)
goto IsITCMInstalled


:IsITCMInstalled
echo.
echo Check for existing ITCM Agent..
echo -------------------------------
set itrm_key_name=HKEY_LOCAL_MACHINE\SOFTWARE\ComputerAssociates\Unicenter ITRM
set itrm_value=InstallDir
for /f "skip=2 tokens=1,2*" %%a in ('reg query "%itrm_key_name%" /v "%itrm_value%" 2^>nul') do (
    set reg_value=%%c)
set itrm_dir=%reg_value%
set reg_value=
if "%itrm_dir%"=="" (
  set itrm_key_name=HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\ComputerAssociates\Unicenter ITRM
  for /f "skip=2 tokens=1,2*" %%a in ('reg query "!itrm_key_name!" /v "!itrm_value!" 2^>nul') do (
    set reg_value=%%c)
  set itrm_dir=!reg_value!
  set reg_value=
  if "!itrm_dir!"=="" (
	echo ITCM agent not installed.
    goto InstallITCM
  ) else (
	set arch=64)
) else (
  set arch=32)
set itrm_value=InstallVersion
for /f "skip=2 tokens=1,2*" %%a in ('reg query "%itrm_key_name%" /v "%itrm_value%" 2^>nul') do (
  set reg_value=%%c)
set itrm_version=%reg_value%
set reg_value=
echo ITCM Install Dir: %itrm_dir%
echo ITCM Version: %itrm_version%
echo Architecture: %arch%-bit
goto Success


:InstallITCM
echo.
echo Installing ITCM Agent..
echo -----------------------
"%cd%\%ITCM_SOURCE_FILES%\DeployWrapper.exe" /DPINST CopiedAgents /qn AGENT_SERVER=%DEFAULT_SCALABILITY_SERVER% ALLUSERS=1
set itcm_install_rc=%errorlevel%
echo Return code:  %itcm_install_rc%
if %itcm_install_rc% gtr 0 (goto InstallITCMFail)
set itrm_key_name=HKEY_LOCAL_MACHINE\SOFTWARE\ComputerAssociates\Unicenter ITRM
set itrm_value=InstallDir
for /f "skip=2 tokens=1,2*" %%a in ('reg query "%itrm_key_name%" /v "%itrm_value%" 2^>nul') do (
  set reg_value=%%c)
set itrm_dir=%reg_value%
set reg_value=
if "%itrm_dir%"=="" (
  set itrm_key_name=HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\ComputerAssociates\Unicenter ITRM
  for /f "skip=2 tokens=1,2*" %%a in ('reg query "!itrm_key_name!" /v "!itrm_value!" 2^>nul') do (
    set reg_value=%%c)
  set itrm_dir=!reg_value!
  set reg_value=
  if "!itrm_dir!"=="" (
	echo ITCM Agent not installed!
    goto InstallITCMFail
  ) else (
    set arch=64)
) else (
  set arch=32)
set itrm_value=InstallVersion
for /f "skip=2 tokens=1,2*" %%a in ('reg query "%itrm_key_name%" /v "%itrm_value%" 2^>nul') do (
  set reg_value=%%c)
set itrm_version=%reg_value%
set reg_value=
echo Install Dir:  %itrm_dir%
echo Version:      %itrm_version%
echo Architecture: %arch%-bit
goto Success

  
:InstallITCMFail
echo.
echo ********************************************
echo Agent install script DID NOT complete successfully.
echo Failed to install the ITCM agent.
echo Log files are located in %temp%
echo ********************************************
endlocal
exit /b %itcm_install_rc%
  

:Success
echo.
echo ********************************************
echo Agent install script completed successfully.
echo ********************************************
endlocal
exit /b 0  
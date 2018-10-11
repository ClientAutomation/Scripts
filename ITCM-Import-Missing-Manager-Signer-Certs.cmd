@echo off
setlocal enableextensions enabledelayedexpansion

REM --------------------------------------------
REM ITCM Manager-Signer Import Script
REM
REM Original Author: 
REM Brian Fontana, Principal Engineer, CA Support
REM
REM Last Updated:
REM 10-Oct 2018 -- Brian Fontana
REM
REM Purpose:
REM To import the missing Manager-Signer certificates
REM into the ITCM Agent certificate store.  OOTB,
REM agents are not installed with the manager-signer
REM certificates, though they are physically present
REM inside of DSM\bin.  This script will run the import
REM statements to import them, as the software inventory
REM scanner will depend on the manager-signer certificate
REM for successful completion of the software scanner.
REM They are required for the intellisig scanner.
REM --------------------------------------------

echo.
echo **********************************************
echo **    Import Manager-Signer Certificates    **
echo **********************************************
echo.

REM Read DSM folder location and determine architecture.
set itrm_key_name=HKEY_LOCAL_MACHINE\SOFTWARE\ComputerAssociates\Unicenter ITRM
set itrm_value=InstallDirProduct
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
	echo ITCM agent not installed, no changes made.
    exit /b 0
  ) else (
	set arch=64)
) else (
  set arch=32)

REM Read ITCM version.
set itrm_value=InstallVersion
for /f "skip=2 tokens=1,2*" %%a in ('reg query "%itrm_key_name%" /v "%itrm_value%" 2^>nul') do (
  set reg_value=%%c)
set itrm_version=%reg_value%
set reg_value=

REM Obtain ITCM version number breakdown
for /F "delims=. tokens=1-4" %%a in ("%itrm_version%") do (
  set /a itrm_major=%%a
  set /a itrm_minor=%%b
  set /a itrm_sp=%%c
  set /a itrm_build=%%d
)

REM Count the number of manager-signer certificates.
set /a certcounter=0
for /f "delims=, tokens=1" %%a IN ('cacertutil list ^| findstr /i "CN=manager signer" ^| findstr /i "Subject"') do (
  set /a certcounter+=1
)

REM Output summary.
echo DSM Dir: %itrm_dir%
echo Version: %itrm_version%
echo Major Version: %itrm_major%
echo Minor Version: %itrm_minor%
echo Service Pack: %itrm_sp%
echo Build Number: %itrm_build%
echo Architecture: %arch%-bit
echo Manager-Signer Count: %certcounter%
echo.

REM Exit condition: r14 SP1 or greater agent with TWO manager-signer certificates
if %certcounter%==2 (
  if %itrm_major% geq 14 (
    if %itrm_minor%==0 (
      if %itrm_sp% geq 1000 (
        echo Manager-Signer certificates already imported^^!
        echo Exiting...
        exit /b 0
      )
    )
  )
)

REM Exit condition: r14 GA, with ONE manager-signer certificate
if %certcounter%==1 (
  if %itrm_major%==14 (
    if %itrm_minor%==0 (
      if %itrm_sp%==0 ( 
        echo Manager-Signer certificates already imported^^!
        echo Exiting...
        exit /b 0
      )
    )
  )
)

REM Exit condition: r12 or prior agent, with ONE manager-signer certificate
if %certcounter%==1 (
  if %itrm_major% leq 12 (
    echo Manager-Signer certificate already imported^^!
    echo Exiting...
    exit /b 0
  )
)

REM Change directory to DSM\bin folder.
cd /d %itrm_dir%\bin

REM Import TWO manager-signer certificates on r14 SP1 or newer
if %itrm_major% geq 14 (
  if %itrm_minor%==0 (
    if %itrm_sp% geq 1000 (
      echo Importing SHA1 and SHA256 certificates..
      cacertutil import -i:itrm_dsm_mngrsgn.cer -it:x509v3 -t:ManagerSigner 
      cacertutil import -i:itrm_dsm_mngrsgn_sha2.cer -it:x509v3 -t:ManagerSigner 
    ) else (
      echo Importing SHA1 certificate..
      cacertutil import -i:itrm_dsm_mngrsgn.cer -it:x509v3 -t:ManagerSigner 
    )
  )
) else (
  echo Importing SHA1 certificate..
  cacertutil import -i:itrm_dsm_mngrsgn.cer -it:x509v3 -t:ManagerSigner  
)

REM kill AM agent, if running.
caf kill amagent >nul 2>&1
taskkill /im amagetsvc.exe /f >nul 2>&1
taskkill /im amsoftscan.exe /f >nul 2>&1
taskkill /im amswsigscan.exe /f >nul 2>&1

REM Trigger full am agent scan.
caf start amagent args -rescan_software -collect >nul 2>&1

REM Exit success.
echo.
echo Script completed successfully^^!
exit /b 0 
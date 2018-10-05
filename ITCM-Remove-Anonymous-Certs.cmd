@Echo off
SetLocal EnableDelayedExpansion

Call :Start>"%~DP0DelAnonymous.txt"

:Start
REM Set User Configurable Variables
	Set CertUtilCmd=cacertutil.exe
	Set ListCMD=%CertUtilCmd% list -v
	
	Set MyError=0
		%ListCMD% >nul
	Set MyError=%Errorlevel%
	If "%MyError%"=="" Set MyError=0
	If %MyError%==0 goto :StartCleanup
	
	Call :FindITCMLOC
	If /I "%FOUNDITCM%"=="True" Set CertUtilCmd=%ITCMPATH%\bin\%CertutilCmd%
	If Exist "%CertUtilCmd%" goto :StartCleanup
	
	Echo "Cannot find ITCM install path or cacertutil.exe, aborting process"
	exit 999
	
:StartCleanup
Echo "Beginning ITCM anonymous certificate processing on %computername% at %Time% on %Date%"

REM Set Unique portion of cert subject you wish to purge
	Set AnonString=OU=itcm-self-signed,O=ca
	Set SubString=Subject
	
REM Initialize needed variables
	Set GotAnon=False
	Set MySkid=Nothing
	Set SubVar=Nothing
	Set Var=Nothing
	
	For /F "tokens=1,2*" %%a in ('%ListCMD%') do (
	Set SubVar=%%a
	Set Var=%%c
	Set AnonFound=False
	Set SubFound=False

	If /I "!GotAnon!"=="True" Echo "Running %CertUtilCmd% remove -skid:!Var!"
	If /I "!GotAnon!"=="True" Echo.
	If /I "!GotAnon!"=="True" %CertUtilCmd% remove -skid:!Var!
	If /I "!GotAnon!"=="True" Set GotAnon=False

	Set MyError=0
		Echo !Var! | findstr /I /C:"%AnonString%" >nul
	Set MyError=!Errorlevel!
	If "!MyError!"=="" Set MyError=0
	If "!MyError!"=="0" Set AnonFound=True

	Set MyError=0
		Echo !SubVar! | findstr /I /C:"%SubString%" >nul
	Set MyError=!Errorlevel!
	If "!MyError!"=="" Set MyError=0
	If "!MyError!"=="0" Set SubFound=True

	If /I "!AnonFound!!SubFound!"=="TrueTrue" Set GotAnon=True
)

Echo "Completing ITCM Anonymous certificate wipe and regen at %Time% on %Date%"

exit 0

:FindITCMLOC
REM Set variables needed to determine ITCM path on the system
	Set ITCMPATH=nothing
	Set ITCMRPATH=nothing
	Set ITCMVAL=InstallDirProduct
	Set FOUNDITCM=False

	Set ITCM64=HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\ComputerAssociates\Unicenter ITRM
	Set ITCM32=HKEY_LOCAL_MACHINE\SOFTWARE\ComputerAssociates\Unicenter ITRM

REM Test for ITCM 64 bit reg path. If not found assume 32 bit system.
	Set MyError=0
		Reg.exe query "%ITCM64%" /v "%ITCMVAL%" >nul
	Set MyError=%Errorlevel%
	If "%MyError%"=="" set MyError=0

	If %MyError%==0 Set ITCMRPATH=%ITCM64%
	If not %MyError%==0 Set ITCMRPATH=%ITCM32%

REM Now try to query the ITCM path value from the registry again to confirm. If it fails, try to guess where ITCM is.
	For /F "skip=2 tokens=1,2*" %%a in ('reg query "%ITCMRPATH%" /v "%ITCMVAL%"') do (
	Set ITCMPATH=%%c)

	If "%ITCMPATH%"=="" Set ITCMPATH=nothing
Echo "ITCM path read as %ITCMPATH%"

	If /I "%ITCMPATH%"=="nothing" Echo "ITCM Path cannot be extracted from registry."
	If /I "%ITCMPATH%"=="nothing" Set ITCMPATH=%Sdroot%\..\
	If Not Exist "%ITCMPATH%" Set ITCMPATH=nothing
	
	If NOT Exist "%ITCMPATH%" ECHO "Unable to find ITCM PATH, process will fail"
	If Exist "%ITCMPATH%" Echo "Was able to find ITCM in %ITCMPATH%" 
	If Exist "%ITCMPATH%" set FOUNDITCM=true
	If "%ITCMPATH:~-1%"=="\" Set ITCMPATH=%ITCMPATH:~0,-1%

goto :eof
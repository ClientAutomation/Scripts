@ECHO Off

REM --------------------------------------------
REM Scalability Server Maintenance Tool
REM By Joe Puccio, Principal Engineer, Support
REM CA Technologoes
REM PUCJO01@CA.COM
REM COMPLETED 5-16-2017
REM LAST UPDATED 9-21-2018
REM --------------------------------------------

SETLOCAL enabledelayedexpansion enableextensions

REM Generate a uniqueness stamp to use as part of log name.
REM Based on the time and date the script is run.
    SET "TimeDate=-%TIME%-%DATE%"
    SET "TimeDate=%TimeDate::=.%"
    SET "TimeDate=%TimeDate:/=-%"
    SET "TimeDate=%TimeDate: =-%"
    SET "TimeDate=%TimeDate:.=_%"

REM Create dynamic log file name based on file name and modified time/date stamp
    SET "Client_Log_Name=%~n0%TimeDate%.log"

REM Set directory where we will store our log files
    SET "Client_log_path=%windir%\temp\SSMaintLogs\"

REM Set number of days logs will be retained
    SET "MaxLogs=5"

REM ----------CLEANUP TASK USER CONFIGURABLE PARAMETERS BEGIN----------
    REM If set to true, all anonymous certificates will be purged and a new one auto-generated.
	SET CLEAN_ANONYMOUS=TRUE
    REM If set to true, the 'CLEANSTART' folder will be generated to clean SD File Transfer Journal information.
	SET USE_CLEANSTART=TRUE
    REM Value is in days. Set to 0 to delete all files of type.
	SET "MAX-DTS_TR-AGE=14"
	REM Value is in days. Set to 0 to delete all files of type.
    SET "MAX-DTS-STS-AGE=14"
	REM Value is in days. Set to 0 to delete all files of type.
    SET "MAX-DTS-STAGE-AGE=14"
	REM Value is in days. Set to 0 to delete all files of type.
    SET "MAXJOBOUTAGE=14"
	REM Specifies the number of files of each specified type to retain after cleanup.
    SET "MIN-AM-FILES=3"
	REM Value is in days. Set to 0 to delete all files of type.
    SET "MAXCOLFILEAGE=21"
	REM Value is in days. Set to 0 to delete all SD folders in activate.
    SET "MAXSDFOLDITEMAGE=21"
	REM Value is in days. Set to 0 to delete all SD files in activate.
    SET "MAXACTIVATEITEMAGE=21"
	REM Value is in days. Set to 0 to delete all DTS .sts tmp files.
    SET "MAXSDTMPAGE=21"
	REM Value is in days. Set to 0 to delete all log files.
    SET "MAXLOGAGE=0"
	REM Set value to determine if only files will be deleted or folders as well.
    SET "AllowDelSubFolders=TRUE"
	REM Set to TRUE to allow script to stop and start CAF where applicable.
	REM The script will still attempt to detect if run by SD or Winoffline and prevent
	REM recycling in those cases.
	SET "AllowManualRestart=FALSE"
REM -----------CLEANUP TASK USER CONFIGURABLE PARAMETERS END-----------
	SET CertUtilCmd=cacertutil.exe
    SET "DTS_TR_PATH=%SDROOT%\ASM\library\dts_tr\"
    SET "DTS_STAT_PATH=%SDROOT%\..\dts\dta\status\"
    SET "DTS_STAGE_PATH=%SDROOT%\..\dts\dta\staging\"
    SET "Activate_Path=%SDROOT%\ASM\library\activate\"
    SET "OUTPUT_PATH=%SDROOT%\ASM\library\output\"
    SET "SDTMP_PATH=%SDROOT%\tmp\"
    SET "SD_D_PATH=%SDROOT%\ASM\D\"
    SET "ITCM_LOG_PATH=%SDROOT%\..\LOGS\"
    SET "SRVDB_PATH=%SDROOT%\..\ServerDB\"
    SET "COLLECT_PATH=%SRVDB_PATH%Sector\collect\"
    SET "SSFW_PATH=%SRVDB_PATH%Sector\SSFW\"
    SET "SSFU_PATH=%SRVDB_PATH%Sector\SSFU\"
    SET "SSFW_DLT_PATH=%SRVDB_PATH%Sector\SSFW\Delta\"
    SET "SSFU_DLT_PATH=%SRVDB_PATH%Sector\SSFU\Delta\"
    SET "DBCACHE_PATH=%SRVDB_PATH%common\"
    SET "DTSSTSEXT=.sts"

REM IF log path does NOT end in a backslash, add one.
    IF /I NOT "%Client_log_path:~-1%"=="\" SET "Client_log_path=%Client_log_path%\"

REM IF the log path does NOT exist, create it.
    IF NOT EXIST "%Client_log_path%" md "%Client_log_path%"

REM IF the log path stil does NOT exist, something is wrong
    IF NOT EXIST "%Client_log_path%" CALL :EXITNOW "Unable to find or create log folder path, %Client_log_path%." 11

REM These values will be used to control how log file management will work.
    SET "FileRoot=%~n0"
    SET "FileExt=%Client_Log_Name:~-4%"
    SET "Searchname=%FileRoot%*%FileExt%"
REM These are initial values for log maintenance variables    
    SET "Lognum=0"
    SET "Oldstlg=nothing"

REM Set the below to prevent user setting max logs to unacceptable values.
REM The number may not be set any higher than 9 or lower than 1
    IF %MaxLogs% GTR 9 SET "MaxLogs=9"
    IF %MaxLogs% LSS 1 SET "MaxLogs=1"

REM Count how many logs we already have
    CALL :COUNTLOGS
        IF %LogNum% EQU 0 GOTO :NOLOGS
REM Not required but proves we are working with dates correctly
    CALL :OLDESTLOG

    IF %Lognum% GEQ (%MaxLogs%-1) CALL :TRIMLOGS

:NOLOGS

REM Full path to log file
    SET "CLIENT_LOG_FULLPATH=%CLIENT_LOG_PATH%%CLIENT_LOG_NAME%"

REM Now set all echoed lines to export to a log file
REM -----------------------------------------------------------------------------------
    CALL :START>"%CLIENT_LOG_FULLPATH%" 2>&1
	Exit 999

:START
ECHO "Starting maintenance run on %Date% at %Time%"

REM -----------------------------------------------------------------------------------

    IF NOT EXIST "%SDROOT%\" CALL :EXITNOW "No Software Delivery Root Folder Found, Aborting" 12

    IF NOT EXIST "%SDROOT%\..\bin\cserver.exe" CALL :EXITNOW "cserver.exe was NOT found in %SDROOT%\..\bin\, a Scalability Server must have that file. Aborting process" 13

	SET "ViaSD=FALSE"
	Set "MustRestart=False"
	
	If /I "%CLEAN_ANONYMOUS%"=="True" Call :CLEANANON

    SET "ExeRunning=FALSE"
    CALL :CHECKEXERUNNING "WinOffline.exe"
    IF /I "%ExeRunning%"=="True" SET "AllowManualRestart=FALSE"
    
    SET "ExeRunning=FALSE"
    CALL :CHECKEXERUNNING "JoeOffline.exe"
    IF /I "%ExeRunning%"=="True" SET "AllowManualRestart=FALSE"

    SET "ExeRunning=FALSE"	
    CALL :CHECKEXERUNNING "sd_jexec.exe"
    IF /I "%ExeRunning%"=="True" SET "AllowManualRestart=FALSE"
	IF /I "%ExeRunning%"=="True" SET ViaSD=True

    SET "ExeRunning=FALSE"
    CALL :CHECKEXERUNNING "cserver.exe"
    IF /I "%AllowManualRestart%%ExeRunning%"=="TrueFalse" ECHO "Attempting to start CAF"
    IF /I "%AllowManualRestart%%ExeRunning%"=="TrueFalse" CALL :STARTCAF

    SET "ExeRunning=FALSE"
    CALL :CHECKEXERUNNING "cserver.exe"
    IF /I "%AllowManualRestart%%ExeRunning%"=="TrueTrue" cserver reset
    IF /I "%AllowManualRestart%%ExeRunning%"=="FalseTrue" cserver reset

    IF /I "%AllowManualRestart%%ExeRunning%"=="TrueFalse" CALL :PURGELOCALDCACHE
    IF /I "%AllowManualRestart%%ExeRunning%"=="FalseFalse" CALL :PURGELOCALDCACHE

    IF /I "%AllowManualRestart%"=="True" CALL :STOPALL
	
	IF /I "%USE_CLEANSTART%"=="TRUE" CALL :CLEANSTARTER

REM CLEANDIR Will clean directories based on age with the ability
REM To protect specified file and/or folder names from deletion.
REM It does NOT support Prefix, Suffix filters or Minimum quantity filters.
REM CLEANDIR reuires seveal parameters to function
REM First the target directory name to be examined; in double quotes.
REM Second is the max age of files to retain where 0 means delete all
REM IF not specified, will default to 90.
REM Third is whether deletions should include deletion of sub-folders.
REM 0 means sub-folders will NOT be deleted. IF not specified, defaults to 0.
REM 1 allows this, but can be overwitten by the global 'AllowDelSubFolders' variable.
REM Fourth is the file and/or folder names to protect from deletion during cleanup
REM This must be specified in a single double quoted list separated by spaces
REM EACH PROTECTED ITEM MUST BE PRECEEDED with either 'Fi:' (file) or 'Fo:' (folder)
REM REPLACE ALL SPACES IN PROTECTED ITEM NAMES WITH '\*' CHARACTERS OR PROC WILL FAIL.
REM Ex. Search directory of 'C:\Program Files(x86)\MyFiles' would STAY this way
REM But to PROTECT any SUB-FOLDERS like '\My Logs\' '\My Apps\' '\My Results\'
REM You would pass 'Fo:My\*Logs Fo:My\*Apps Fo:My\*Results'
    IF EXIST "%DTS_TR_PATH%" CALL :CLEANDIR "%DTS_TR_PATH%" %MAX-DTS_TR-AGE% 0 ""
		Set "CleanParams=Fo:lgzip Fo:scripts Fi:scripts.zip"
		If /I NOT "%ViaSD%"=="True" GOTO :NOTVIASD
			Set MyCurPath=%~dp0
			CD /D "%MyCurPath%"
			CD..
			Set "MyCurPath=%CD%"
			CD /D "%~dp0"
			Set MyCurPath=%MyCurPath: =\*%
			Set "CleanParams=Fo:lgzip Fo:scripts Fi:scripts.zip Fo:%MyCurPath%\"
:NOTVIASD
    IF EXIST "%Activate_Path%" CALL :CLEANDIR "%Activate_Path%" %MaxActivateItemAge% 1 "%CleanParams%"
    IF EXIST "%OUTPUT_PATH%" CALL :CLEANDIR "%OUTPUT_PATH%" %MAXJOBOUTAGE% 1 ""
    IF EXIST "%SDTMP_PATH%" CALL :CLEANDIR "%SDTMP_PATH%" %MaxSDTmpAge% 1 ""
    IF EXIST "%SD_D_PATH%" CALL :CLEANDIR "%SD_D_PATH%" %MaxSDFoldItemAge% 1 ""
    IF EXIST "%ITCM_LOG_PATH%" CALL :CLEANDIR "%ITCM_LOG_PATH%" %MaxLogAge% 1  ""

    IF EXIST "%DTS_STAT_PATH%" CALL :CLEANDIR "%DTS_STAT_PATH%" %MAX-DTS-STS-AGE% 1 "Fi:INDEX"
    IF EXIST "%DTS_STAT_PATH%" CALL :CHKINDEX
    
    IF NOT EXIST "%DTS_STAGE_PATH%" GOTO :SKIPSTAGE
    
    SET "FilesOfType=0"
    CALL :COUNTFILESOFTYPE "%DTSSTSEXT%" "%DTS_STAT_PATH%"
    IF %FilesOfType% LEQ 0 CALL :CLEANDIR "%DTS_STAGE_PATH%" 0 1 ""
    IF %FilesOfType% GTR 0 CALL :CLEANDIR "%DTS_STAGE_PATH%" %MAX-DTS-STAGE-AGE% 1 ""

:SKIPSTAGE
    IF EXIST "%COLLECT_PATH%00000001\" CALL :CLEANDIR "%COLLECT_PATH%00000001\" %MAXCOLFILEAGE% 0 ""
    IF EXIST "%COLLECT_PATH%00000002\" CALL :CLEANDIR "%COLLECT_PATH%00000002\" %MAXCOLFILEAGE% 0 ""

REM CLEANDIR_W_FLT Will clean directories based on quantity and filter criteria, NOT age
REM CLEANDIR_W_FLT requires several parameters to function
REM First, the directory to examine. Will exit IF not specified.
REM Second the minimum number of files to retain; of each type in the case of Prefix and Suffix filters
REM Will Default to 90 IF not passed.
REM Third is the actual filter(s) in a single double quoted list with spaces between each.
REM IF both Prefixes and Suffixes are specified, then only combinations of both will be searched for.
REM In each case an 'S:' or 'P:' MUST preceed each Item to mark it as Prefix or Suffix. IF the first two
REM letters do not match one of those two strings, the filter will be IGNORED.
REM This procedure DOES NOT SUPPORT PREFIXES and/or SUFFIXES with SPACES IN THEM.
    IF EXIST "%SSFW_PATH%" CALL :CLEANDIR_W_FLT "%SSFW_PATH%" %MIN-AM-FILES% "P:LWA_W00 P:W00 P:X00 S:ZML S:DAT"
    IF EXIST "%SSFU_PATH%" CALL :CLEANDIR_W_FLT "%SSFU_PATH%" %MIN-AM-FILES% "P:L00 P:X00 S:ZML S:DAT"
    IF EXIST "%SSFW_DLT_PATH%" CALL :CLEANDIR_W_FLT "%SSFW_DLT_PATH%" %MIN-AM-FILES% "P:DLT_W P:DLT_X S:ZML S:DAT"
    IF EXIST "%SSFU_DLT_PATH%" CALL :CLEANDIR_W_FLT "%SSFU_DLT_PATH%" %MIN-AM-FILES% "P:DLT_L P:DLT_M S:ZML S:DAT"

If /I "%MustRestart%"=="True" CALL :STARTCAF

ECHO "Maintenance activites have completed at %Time% on %Date%"

	Exit

GOTO :EOF

:CHECKEXERUNNING
REM ECHO "Entering CHECKEXERUNNING"
    SET "ExeToChk=%1"

	IF %ExeToChk%xxx==xxx ECHO "No Executable name specified; exiting CheckExeRunning"
	IF %ExeToChk%xxx==xxx GOTO :EOF
	IF %ExeToChk%xxx==""xxx ECHO "No Executable name specified; exiting CheckExeRunning"
	IF %ExeToChk%xxx==""xxx GOTO :EOF

    SET ExeToChk=%ExeToChk:"=%
    SET "ExeRunning=FALSE"

    SET "MyError=0"
        tasklist | findstr /I /B /C:"%ExeToChk%"
    SET "MyError=%Errorlevel%"
    IF "%MyError%"=="" SET "MyError=0"

    IF %MyError% EQU 0 SET "ExeRunning=TRUE"

GOTO :EOF

:STARTCAF
ECHO "Starting all ITCM processes"
SET ExeRunning=FALSE

    CALL :CHECKEXERUNNING "cam.exe"
    IF /I "%ExeRunning%"=="True" ECHO "CAM is already running"
    IF /I "%ExeRunning%"=="False" Cam.exe change auto & cam start -c -l

    CALL :CHECKEXERUNNING "caf.exe"
    IF /I "%ExeRunning%"=="True" ECHO "CAF is already running"
    IF /I "%ExeRunning%"=="False" caf.exe start>nul

    IF /I "%ExeRunning%"=="False" CALL :CHECKEXERUNNING "caf.exe"
    IF /I "%ExeRunning%"=="True" ECHO "CAF is now running"
    IF /I "%ExeRunning%"=="False" ECHO "Caf start was issued but caf.exe not found in tasklist. Please investigate"
    
GOTO :EOF

:CLEANSTARTER
	IF NOT EXIST "%SDROOT%\ASM\DTABASE\FTM_JOURNALS" ECHO "Required path, %SDROOT%\ASM\DTABASE\FTM_JOURNALS, not found, aborting cleanstart procedure"
	IF NOT EXIST "%SDROOT%\ASM\DTABASE\FTM_JOURNALS" GOTO: EOF
	
	IF EXIST "%SDROOT%\ASM\DTABASE\FTM_JOURNALS\CLEANSTART" ECHO "Cleanstart folder already exists, will take no action. Aborting cleanstart procedure"
	IF EXIST "%SDROOT%\ASM\DTABASE\FTM_JOURNALS\CLEANSTART" GOTO :EOF
	
	IF NOT EXIST "%SDROOT%\ASM\DTABASE\FTM_JOURNALS\CLEANSTART" MD "%SDROOT%\ASM\DTABASE\FTM_JOURNALS\CLEANSTART"
	
	IF NOT EXIST "%SDROOT%\ASM\DTABASE\FTM_JOURNALS\CLEANSTART" ECHO "Failed to create folder, %SDROOT%\ASM\DTABASE\FTM_JOURNALS\CLEANSTART, aborting cleanstart procedure"
	IF NOT EXIST "%SDROOT%\ASM\DTABASE\FTM_JOURNALS\CLEANSTART" GOTO :EOF
	
	ECHO "Cleanstart folder generation successful"

GOTO :EOF

:STOPALL
ECHO "Stopping all ITCM processes"
	SET MustRestart=True
	SET ExeRunning=FALSE
    CALL :CHECKEXERUNNING "egc30n.exe"
    IF /I "%ExeRunning%"=="True" Taskkill /F /IM egc30n.exe>nul

	SET ExeRunning=FALSE
    CALL :CHECKEXERUNNING "CAF.exe"
    IF /I NOT "%ExeRunning%"=="True" GOTO :CAFDOWN
   
ECHO "Stopping systray via caf if supported"
	SET MyError=0
		CAF stop cfsystray>nul
	SET MyError=%errorlevel%
	IF "%MyError%"=="" SET MyError=0

	If NOT %MyError% EQU 0 Taskkill /F /IM cfsystray.exe>nul

ECHO "Attempting caf stop all if supported
	SET MyError=0
		CAF STOP all>nul
	SET MyError=%errorlevel%
	IF "%MyError%"=="" SET MyError=0
	
	IF %MyError% EQU 0 GOTO :SKIPTOKILL

ECHO "Stopping external ITCM services"
    CAF stop /ext>nul

ECHO "Stopping CAF"
    CAF STOP>nul

:SKIPTOKILL
    CAF KILL ALL>nul

:CAFDOWN
    CALL :CHECKEXERUNNING "CAM.exe"
    IF /I "%ExeRunning%"=="False" GOTO :CAMDOWN
        cam change disabled 
        cam stop
    
    CALL :CHECKEXERUNNING "CAM.exe"
    IF /I "%ExeRunning%"=="True" Taskkill /F /IM cam.exe>nul

:CAMDOWN
    CALL :CHECKEXERUNNING "CSAMPMUX.exe"
    IF /I "%ExeRunning%"=="False" GOTO :PMUXDOWN
        csampmux stop

    CALL :CHECKEXERUNNING "CSAMPMUX.exe"
    IF /I "%ExeRunning%"=="True" Taskkill /F /IM csampmux.exe>nul
    
:PMUXDOWN
REM Even though CAM may restart, better to be safe than sorry
        cam change auto

GOTO :EOF

:CHKINDEX
ECHO "About to check DTS index file"

    IF NOT EXIST "%DTS_STAT_PATH%" ECHO "Required path, %DTS_STAT_PATH%, NOT found. Skipping INDEX check"
    IF NOT EXIST "%DTS_STAT_PATH%" GOTO :EOF

    SET "FilesOfType=0"
    CALL :COUNTFILESOFTYPE "%DTSSTSEXT%" "%DTS_STAT_PATH%"
    IF %FilesOfType% GTR 0 ECHO "There are %FilesOfType% files in %DTS_STAT_PATH% with a %DTSSTSEXT% extension so the INDEX file will not be recreated"
    IF %FilesOfType% GTR 0 GOTO :EOF

    CD /D "%DTS_STAT_PATH%"

    IF NOT EXIST "INDEX" ECHO "INDEX file NOT found in %DTS_STAT_PATH%; Will attempt to create new one"
    IF NOT EXIST "INDEX" GOTO :MAKEINDEX

    DEL /F /Q INDEX

    IF NOT EXIST "INDEX" ECHO "Deletion of old INDEX file has completed successfully"

    IF EXIST "INDEX" ECHO "Failed to delete INDEX file, unable to purge and recreate"
    IF EXIST "INDEX" GOTO :EOF

:MAKEINDEX

Echo.>INDEX

    IF NOT EXIST "INDEX" ECHO " ">INDEX
    IF NOT EXIST "INDEX" ECHO "Failed to recreate INDEX file. DTS May NOT be functional"
    IF NOT EXIST "INDEX" GOTO :EOF

ECHO "New DTS INDEX file created successfully"

GOTO :EOF

:COUNTFILESOFTYPE
REM ECHO "Entering COUNTFILESOFTYPE"
SET "FileExt=%1"
SET "ExtPath=%2"

IF %FileExt%xxx==xxx ECHO "No arguements passed to CountFilesOfType; exiting function"
IF %FileExt%xxx==xxx GOTO :EOF
IF %FileExt%xxx==""xxx ECHO "No arguements passed to CountFilesOfType; exiting function"
IF %FileExt%xxx==""xxx GOTO :EOF

IF %ExtPath%xxx==xxx ECHO "No path passed to CountFilesOfType; exiting function"
IF %ExtPath%xxx==xxx GOTO :EOF
IF %ExtPath%xxx==""xxx ECHO "No path passed to CountFilesOfType; exiting function"
IF %ExtPath%xxx==""xxx GOTO :EOF

SET FileExt=%FileExt:"=%
SET ExtPath=%ExtPath:"=%

IF /I Not "%FileExt:~0,1%"=="." SET "FileExt=.%FileExt%"

SET "FilesOfType=0"

	IF NOT EXIST "%ExtPath%" ECHO "Provided path, %ExtPath%, Does not exist unable to search for files. Exiting."
	IF NOT EXIST "%ExtPath%" GOTO :EOF

	CD /D "%ExtPath%"

IF NOT EXIST "*%FileExt%" ECHO "0 files found with a %FileExt% extension, in path %ExtPath%"
IF NOT EXIST "*%FileExt%" SET "FilesOfType=0"

For %%a in ('Dir "*%FileExt%" /A:-D /B') Do (SET /a FilesOfType=!FilesOfType!+1)

ECHO "There are %FilesOfType% files with a %FileExt% extension in %ExtPath%"

GOTO :EOF

REM CLEANDIR Will clean directories based on age with the ability
REM To protect specified file and/or folder names from deletion.
REM It does NOT support Prefix, Suffix filters or Minimum quantity filters.
REM CLEANDIR reuires seveal parameters to function
REM First the target directory name to be examined; in double quotes.
REM Second is the max age of files to retain where 0 means delete all
REM IF not specified, will default to 90.
REM Third is whether deletions should include deletion of sub-folders.
REM 0 means sub-folders will NOT be deleted. IF not specified, defaults to 0.
REM 1 allows this, but can be overwitten by the global 'AllowDelSubFolders' variable.
REM Fourth is the file and/or folder names to protect from deletion during cleanup
REM This must be specified in a single double quoted list separated by spaces
REM EACH PROTECTED ITEM MUST BE PRECEEDED with either 'Fi:' (file) or 'Fo:' (folder)
REM REPLACE ALL SPACES IN PROTECTED ITEM NAMES WITH '\*' CHARACTERS OR PROC WILL FAIL.
REM Ex. Search directory of 'C:\Program Files(x86)\MyFiles' would STAY this way
REM But to PROTECT any SUB-FOLDERS like '\My Logs\' '\My Apps\' '\My Results\'
REM You would pass 'Fo:My\*Logs Fo:My\*Apps Fo:My\*Results'
:CLEANDIR
REM ECHO "Entering CLEANDIR"
	SET SkipFiProt=FALSE
	SET SkipFoProt=FALSE

    SET "DirToCleanCLDR=%1"

    IF %DirToCleanCLDR%xxx==xxx ECHO "No directory specified to clean, exiting CLEANDIR"
    IF %DirToCleanCLDR%xxx==xxx GOTO :EOF
    IF %DirToCleanCLDR%xxx==""xxx ECHO "No directory specified to clean, exiting CLEANDIR"
    IF %DirToCleanCLDR%xxx==""xxx GOTO :EOF

	SET DirToCleanCLDR=%DirToCleanCLDR:"=%

    IF NOT EXIST "%DirToCleanCLDR%" ECHO Directory to clean specified, %DirToCleanCLDR%, has not been found, aborting procedure
    IF NOT EXIST "%DirToCleanCLDR%" GOTO :EOF

    SET "MaxAge=%2"
    IF %MaxAge%xxx==""xxx ECHO "No Max Age passed to DirToCleanCLDR, aborting procedure"
    IF %MaxAge%xxx==""xxx GOTO :EOF
    IF %MaxAge%xxx==xxx ECHO "No Max Age passed to DirToCleanCLDR, aborting procedure"
    IF %MaxAge%xxx==xxx GOTO :EOF

	SET MaxAge=%MaxAge:"=%

    SET "DelFolders=%3"
    IF %DelFolders%xxx==""xxx ECHO "No DelFolders value passed. Setting to 0 to disable file deletion."
    IF %DelFolders%xxx==""xxx SET "DelFolders=0"
    IF %DelFolders%xxx==xxx ECHO "No DelFolders value passed. Setting to 0 to disable file deletion."
    IF %DelFolders%xxx==xxx SET "DelFolders=0"

	SET DelFolders=%DelFolders:"=%

    SET "ProtectedItems=%4"
    IF %ProtectedItems%xxx==""xxx ECHO "No items to protect have been currently specified"
	IF %ProtectedItems%xxx==""xxx SET SkipFiProt=TRUE
	IF %ProtectedItems%xxx==""xxx SET SkipFoProt=TRUE
    IF %ProtectedItems%xxx==""xxx GOTO :LEAVEITBLANK
    IF %ProtectedItems%xxx==xxx ECHO "No items to protect have been currently specified"
	IF %ProtectedItems%xxx==xxx SET SkipFiProt=TRUE
	IF %ProtectedItems%xxx==xxx SET SkipFoProt=TRUE
    IF %ProtectedItems%xxx==xxx GOTO :LEAVEITBLANK

	SET ProtectedItems=%ProtectedItems:"=%

    SET "ModProt=%ProtectedItems:\*= %"

ECHO "Will protect these items %ModProt%"
ECHO.

:LEAVEITBLANK

	SET FULLSKIP=FALSE
    IF /I "%SkipFiProt%%SkipFoProt%"=="TRUETRUE" Set FULLSKIP=TRUE
	SET LASTISOLD=FALSE
	SET LASTFOISOLD=FALSE

REM Process Files Only
    CD/D "%DirToCleanCLDR%"
	SET "FileToChk="

    For /F "Tokens=*" %%a in ('dir /A:-D /B /O:-D') do (
        SET "FileToChk=%%a"
		SET "KeepFile=FALSE"
        SET "FileGone=FALSE"
        SET "ProtFiItm=FALSE"
		SET "SkipFiProt=FALSE"

        IF NOT EXIST "!FileToChk!" ECHO "!FileToChk! not found in %DirToCleanCLDR%, skipping."
        IF NOT EXIST "!FileToChk!" SET "ProtFiItm=TRUE"

		IF /I "!LASTISOLD!"=="FALSE" (
			IF EXIST "!FileToChk!" CALL :RETAINFILE %MaxAge% "!FileToChk!" "%DirToCleanCLDR%"
			IF /I "!KeepFile!"=="True" ECHO "Will not remove file !FileToChk!"
			IF /I "!KeepFile!"=="True" SET "SkipFiProt=TRUE"
			IF /I "!KeepFile!"=="True" SET "ProtFiItm=TRUE"
			IF /I "!KeepFile!"=="False" SET "LASTISOLD=TRUE"
		)

		IF /I "%FULLSKIP%"=="FALSE" (
			IF /I "!ProtFiItm!!SkipFiProt!"=="FalseFalse" CALL :CHECKPROTFI "%DirToCleanCLDR%" "!FileToChk!" "%ProtectedItems%"
			IF /I "!ProtFiItm!"=="True" SET "KeepFile=TRUE"
		)

        IF /I "!ProtFiItm!"=="True" ECHO "Skipping Deletion of protected file !FileToChk!"
        IF /I "!ProtFiItm!"=="False" ECHO "Deleting file, !FileToChk! in %DirToCleanCLDR%"
        IF /I "!ProtFiItm!"=="False" Del /F /Q "!FileToChk!"
        
        IF EXIST "!FileToChk!" SET "FileGone=FALSE"
        IF NOT EXIST "!FileToChk!" SET "FileGone=TRUE"

        IF /I "!ProtFiItm!!FileGone!"=="FalseTrue" ECHO "File, !FileToChk!, deleted successfully"
        IF /I "!ProtFiItm!!FileGone!"=="FalseFalse" ECHO "Attempt to delete file, !FileToChk!, has failed"
    )

    IF /I "%AllowDelSubFolders%"=="False" ECHO "Sub-folder deletion in %DirToCleanCLDR% has been disabled globally. No sub-directories will be removed"
    IF /I "%AllowDelSubFolders%"=="False" GOTO :NOFOLDDELS
    IF %DelFolders% EQU 0 ECHO "Sub-folder deletion in %DirToCleanCLDR% has been disabled. No sub-directories will be removed"
    IF %DelFolders% EQU 0 GOTO :NOFOLDDELS

REM Now process folders
	CD/D "%DirToCleanCLDR%"
    SET "DirToChk="
	
    For /F "Tokens=*" %%a in ('dir /A:D /B /O:-D') do (
        SET "DirToChk=%%a"
		SET "KeepFold=FALSE"
        SET "DirGone=FALSE"
        SET "ProtFoItm=FALSE"
		SET "SkipFoProt=FALSE"

        IF NOT EXIST "!DirToChk!" ECHO "!DirToChk! not found in %DirToCleanCLDR%, skipping."
        IF NOT EXIST "!DirToChk!" SET "ProtFoItm=TRUE"

		IF /I "!LASTFOISOLD!"=="FALSE" (
			IF EXIST "!DirToChk!" CALL :RETAINFOLDER %MaxAge% "!DirToChk!" "%DirToCleanCLDR%"
			IF /I "!KeepFold!"=="True" ECHO "Will not remove folder !DirToChk!"
			IF /I "!KeepFold!"=="True" SET "SkipFoProt=TRUE"
			IF /I "!KeepFold!"=="True" SET "ProtFoItm=TRUE"
			IF /I "!KeepFold!"=="False" SET "LASTFOISOLD=TRUE"
		)

		IF /I "%FULLSKIP%"=="FALSE" (
			IF /I "!ProtFoItm!!SkipFoProt!"=="FalseFalse" CALL :CHECKPROTFO "%DirToCleanCLDR%" "!DirToChk!" "%ProtectedItems%"
			IF /I "!ProtFoItm!"=="True" SET "KeepFold=TRUE"
		)
		
		IF /I "!ProtFoItm!"=="True" ECHO "Skipping Deletion of protected folder !DirToChk!"
        IF /I "!ProtFoItm!"=="False" ECHO "Deleting folder, !DirToChk! in %DirToCleanCLDR%"
        IF /I "!ProtFoItm!"=="False" RD /Q /S "!DirToChk!"		

		IF EXIST "!DirToChk!" SET "DirGone=FALSE"
		IF NOT EXIST "!DirToChk!" SET "DirGone=TRUE"
        
        IF /I "!ProtFoItm!!DirGone!"=="FalseTrue" ECHO "Directory, !DirToChk!, deleted successfully"
        IF /I "!ProtFoItm!!DirGone!"=="FalseFalse" ECHO "Attempt to delete directory, !DirToChk!, has failed"
    )

:NOFOLDDELS

GOTO :EOF

REM CLEANDIR_W_FLT Will clean directories based on quantity and filter criteria, NOT age
REM CLEANDIR_W_FLT requires several parameters to function
REM First, the directory to examine. Will exit IF not specified.
REM Second the minimum number of files to retain; of each type in the case of Prefix and Suffix filters
REM Third is the actual filter(s) in a single double quoted list with spaces between each.
REM IF both Prefixes and Suffixes are specified, then only combinations of both will be searched for.
REM In each case an 'S:' or 'P:' MUST preceed each Item to mark it as Prefix or Suffix.
REM IF the first two letters do not match one of those two strings, the filter will be IGNORED.
REM This procedure DOES NOT SUPPORT PREFIXES and/or SUFFIXES with SPACES IN THEM.
:CLEANDIR_W_FLT
REM ECHO "Entering CLEANDIR_W_FLT"
    SET "DirToClean=%1"

    IF %DirToClean%xxx==""xxx ECHO "No directory passed to CLEANDIR_W_FLT, aborting procedure"
    IF %DirToClean%xxx==""xxx GOTO :EOF
    IF %DirToClean%xxx==xxx ECHO "No directory passed to CLEANDIR_W_FLT, aborting procedure"
    IF %DirToClean%xxx==xxx GOTO :EOF

	SET DirToClean=%DirToClean:"=%

    IF NOT EXIST "%DirToClean%" ECHO "Directory, %DirToClean%, has not been found, aborting procedure"
    IF NOT EXIST "%DirToClean%" GOTO :EOF

    SET "MinFiles=%2"
    IF %MinFiles%xxx==""xxx ECHO "No minimum number of files specified, aborting procedure"
    IF %MinFiles%xxx==""xxx GOTO :EOF
    IF %MinFiles%xxx==xxx ECHO "No minimum number of files specified, aborting procedure"
    IF %MinFiles%xxx==xxx GOTO :EOF

	SET MinFiles=%MinFiles:"=%

    SET "Filters=%3"
    IF %Filters%xxx==""xxx ECHO "No filters specified, aborting procedure"
    IF %Filters%xxx==""xxx GOTO :EOF
    IF %Filters%xxx==xxx ECHO "No filters specified, aborting procedure"
    IF %Filters%xxx==xxx GOTO :EOF

	SET Filters=%Filters:"=%

ECHO "Directory to clean with filters is %DirToClean%"
ECHO "Will use the following filters %Filters%"
Echo.

    SET "PList="
    SET "SList="
    SET "TotP=0"
    SET "TotS=0"
    SET "FltType="
    SET "Pfound=FALSE"
    SET "Sfound=FALSE"

    CD /D "%DirToClean%"

    FOR %%a in (%Filters%) do (
        SET "TmpFlt=%%a"
        IF /I "!TmpFlt:~0,2!"=="P:" SET "Pfound=TRUE"
        IF /I "!TmpFlt:~0,2!"=="P:" SET "PList=!Plist!!TmpFlt:~2! "
        IF /I "!TmpFlt:~0,2!"=="P:" SET /a TotP=TotP+1
        IF /I "!TmpFlt:~0,2!"=="S:" SET "Sfound=TRUE"
        IF /I "!TmpFlt:~0,2!"=="S:" SET "SList=!Slist!!TmpFlt:~2! "
        IF /I "!TmpFlt:~0,2!"=="S:" SET /a TotS=TotS+1
    )

REM IF the compiled list variable ends in a white space, remove it
    IF "%PList:~-1%"==" " SET "Plist=%Plist:~,-1%"
    IF "%SList:~-1%"==" " SET "Slist=%Slist:~,-1%"

    IF /I "%Pfound%%Sfound%"=="TrueTrue" SET "FltType=2"
    IF /I "%Pfound%%Sfound%"=="TrueFalse" SET "FltType=0"
    IF /I "%Pfound%%Sfound%"=="FalseTrue" SET "FltType=1"
    IF /I "%Pfound%%Sfound%"=="FalseFalse" ECHO "No prefixes or suffixes found. Exiting procedure"
    IF /I "%Pfound%%Sfound%"=="FalseFalse" GOTO :EOF

    IF %FltType% EQU 0 GOTO :CHECKPREFIX
    IF %FltType% EQU 1 GOTO :CHECKSUFFIX

ECHO "There are a total of %TotP% prefixes and %TotS% suffixes to filter"
    SET "LessThanDelNum=FALSE"
    SET "FiltiThere=FALSE"
    SET "FiltiGone=FALSE"
    
    CD /D "%DirToClean%"
    FOR %%w in (%PList%) do (
        SET "MyPref=%%w"
        FOR %%x in (%SList%) do (
            SET "TotPNSCnt=0"
            SET "MySuff=%%x"
            FOR /F %%a in ('dir "!MyPref!*!MySuff!" /A:-D /B /O:D /T:W') do (SET /a TotPNSCnt=TotPNSCnt+1)
            IF !TotPNSCnt! LEQ %MinFiles% SET "DelNum=0"
            IF !TotPNSCnt! LEQ %MinFiles% ECHO "Will Not Delete any files from results of 'dir !MyPref!*!MySuff!' as minimum file treshold of %MinFiles% has not been exceeded"
            IF !TotPNSCnt! GTR %MinFiles% SET /a DelNum=!TotPNSCnt!-%MinFiles%
            IF !TotPNSCnt! GTR %MinFiles% ECHO "Will Delete up to !DelNum! files from results of 'dir !MyPref!*!MySuff!'"
            SET "Count=0"
            FOR /F %%g in ('dir "!MyPref!*!MySuff!" /A:-D /B /O:D /T:W') do (
                SET "FILTI=%%g"
                IF EXIST "!FILTI!" SET "FiltiThere=TRUE"
                IF /I "!FiltiThere!"=="True" SET /a Count=Count+1
                IF !Count! LEQ !DelNum! SET "LessThanDelNum=TRUE"
                IF !Count! GTR !DelNum! SET "LessThanDelNum=FALSE"
                IF /I "!FiltiThere!!LessThanDelNum!"=="TrueTrue" ECHO "Deleting file !FILTI! as there are too many files and it is currently the oldest in %DirToClean%"
                IF /I "!FiltiThere!!LessThanDelNum!"=="TrueTrue" DEL /F /Q "!FILTI!"
                IF NOT EXIST "!FILTI!" SET "FiltiGone=TRUE"
                IF EXIST "!FILTI!" SET "FiltiGone=FALSE"
                IF /I "!FiltiThere!!LessThanDelNum!!FiltiGone!"=="TrueTrueTrue" ECHO "Deletion of !FILTI!, from %DirToClean%, was successful"
                IF /I "!FiltiThere!!LessThanDelNum!!FiltiGone!"=="TrueTrueFalse" ECHO "Deletion of !FILTI!, from %DirToClean%, has failed"
            )
        )
    )

GOTO :SKIPREST

:CHECKPREFIX
ECHO "There are a total of %TotP% prefixes to filter"
    SET "LessThanDelNumPFX=FALSE"
    SET "FiltiTherePFX=FALSE"
    SET "FiltiGonePFX=FALSE"
    
    CD /D "%DirToClean%"
    FOR %%w in (%PList%) do (
        SET "MyPFX=%%w"
        SET "TotPreCnt=0"
        FOR /F %%a in ('dir "!MyPFX!*" /A:-D /B /O:D /T:W') do (SET /a TotPreCnt=TotPreCnt+1)
        IF !TotPreCnt! LEQ %MinFiles% SET /a DelNumCPFX=0
        IF !TotPreCnt! LEQ %MinFiles% ECHO "Will Not Delete any files from results of 'dir !MyPFX!*' as minimum file treshold of %MinFiles% has not been exceeded in %DirToClean%"
        IF !TotPreCnt! GTR %MinFiles% SET /a DelNumCPFX=!TotPreCnt!-%MinFiles%
        IF !TotPreCnt! GTR %MinFiles% ECHO "Will Delete the oldest !DelNumCPFX! files from results of 'dir !MyPFX!*' in %DirToClean%"
        SET CountPFX=0
        FOR /F %%g in ('dir "!MyPFX!*" /A:-D /B /O:D /T:W') do (
            SET "FILTIPFX=%%g"
            IF EXIST "!FILTIPFX!" SET "FiltiTherePFX=TRUE"
            IF NOT EXIST "!FILTIPFX!" SET "FiltiTherePFX=FALSE"
            IF /I "!FiltiTherePFX!"=="True" SET /a CountPFX=CountPFX+1
            IF !CountPFX! LEQ !DelNumCPFX! SET "LessThanDelNumPFX=TRUE"
            IF !CountPFX! GTR !DelNumCPFX! SET "LessThanDelNumPFX=FALSE"
            IF /I "!FiltiTherePFX!!LessThanDelNumPFX!"=="TrueTrue" ECHO "Deleting file !FILTIPFX! from %DirToClean% as minimum files is exceeded and this is currently oldest"
            IF /I "!FiltiTherePFX!!LessThanDelNumPFX!"=="TrueTrue" DEL /F /Q "!FILTIPFX!"
            IF NOT EXIST "!FILTIPFX!" SET "FiltiGonePFX=TRUE"
            IF EXIST "!FILTIPFX!" SET "FiltiGonePFX=FALSE"
            IF /I "!FiltiTherePFX!!LessThanDelNumPFX!!FiltiGonePFX!"=="TrueTrueTrue" ECHO "Deletion of !FILTIPFX!, from %DirToClean%, was successful"
            IF /I "!FiltiTherePFX!!LessThanDelNumPFX!!FiltiGonePFX!"=="TrueTrueFalse" ECHO "Deletion of !FILTIPFX!, from %DirToClean%, has failed"
        )
    )

GOTO :SKIPREST

:CHECKSUFFIX
ECHO "There are a total of %TotS% suffixes to filter"
    SET "LessThanDelNumSFX=FALSE"
    SET "FiltiThereSFX=FALSE"
    SET "FiltiGoneSFX=FALSE"

    CD /D "%DirToClean%"
    FOR %%x in (%SList%) do (
        SET "MySFX=%%x"
        SET "TotSufCnt=0"
        FOR /F %%a in ('dir "*!MySFX!" /A:-D /B /O:D /T:W') do (SET /a TotSufCnt=TotSufCnt+1)
        IF !TotSufCnt! LEQ %MinFiles% SET /a DelNumCSFX=0
        IF !TotSufCnt! LEQ %MinFiles% ECHO "Will Not Delete any files from results of 'dir *!MySFX!' as minimum file treshold of %MinFiles% has not been exceeded"
        IF !TotSufCnt! GTR %MinFiles% SET /a DelNumCSFX=!TotSufCnt!-%MinFiles%
        IF !TotSufCnt! GTR %MinFiles% ECHO "Will Delete !DelNumCSFX! files from results of 'dir *!MySFX!'"
        SET CountSFX=0
        FOR /F %%g in ('dir "*!MySFX!" /A:-D /B /O:D /T:W') do (
            SET "FILTISFX=%%g"
            IF EXIST "!FILTISFX!" SET "FiltiThereSFX=TRUE"
            IF NOT EXIST "!FILTISFX!" SET "FiltiThereSFX=FALSE"
            IF /I "!FiltiThereSFX!"=="True" SET /a CountSFX=CountSFX+1
            IF !CountSFX! LEQ !DelNumCSFX! SET "LessThanDelNumSFX=TRUE"
            IF !CountSFX! GTR !DelNumCSFX! SET "LessThanDelNumSFX=FALSE"
            IF /I "!FiltiThereSFX!!LessThanDelNumSFX!"=="TrueTrue" ECHO "Deleting file !FILTISFX! from %DirToClean% as minimum files is exceeded and this is currently oldest"
            IF /I "!FiltiThereSFX!!LessThanDelNumSFX!"=="TrueTrue" DEL /F /Q "!FILTISFX!"
            IF NOT EXIST "!FILTISFX!" SET "FiltiGoneSFX=TRUE"
            IF EXIST "!FILTISFX!" SET "FiltiGoneSFX=FALSE"
            IF /I "!FiltiThereSFX!!LessThanDelNumSFX!!FiltiGoneSFX!"=="TrueTrueTrue" ECHO "Deletion of !FILTISFX!, from %DirToClean%, was successful"
            IF /I "!FiltiThereSFX!!LessThanDelNumSFX!!FiltiGoneSFX!"=="TrueTrueFalse" ECHO "Deletion of !FILTISFX!, from %DirToClean%, has failed"
        )
    )
:SKIPREST
GOTO :EOF

:CHECKPROTFI
REM ECHO "Entering CHECKPROTFI"
    SET "ProtFiItm=FALSE"

    SET "WrkngDirFi=%1"
    IF %WrkngDirFi%xxx==""xxx ECHO "No directory passed to CheckProtFi, aborting procedure"
    IF %WrkngDirFi%xxx==""xxx GOTO :EOF
    IF %WrkngDirFi%xxx==xxx ECHO "No directory passed to CheckProtFi, aborting procedure"
    IF %WrkngDirFi%xxx==xxx GOTO :EOF

	SET WrkngDirFi=%WrkngDirFi:"=%

    IF NOT EXIST "%WrkngDirFi%" ECHO "Target directory, %WrkngDirFi%, not found. Aborting CheckProtFi"
    IF NOT EXIST "%WrkngDirFi%" GOTO :EOF

    CD /D "%WrkngDirFi%"

    SET "ChkFiItm=%2"
    IF %ChkFiItm%xxx==""xxx ECHO "No file found to check, aborting CheckProtFi"
    IF %ChkFiItm%xxx==""xxx GOTO :EOF
    IF %ChkFiItm%xxx==xxx ECHO "No file found to check, aborting CheckProtFi"
    IF %ChkFiItm%xxx==xxx GOTO :EOF

	SET ChkFiItm=%ChkFiItm:"=%

    SET "ProtListFi=%3"
    IF %ProtListFi%xxx==""xxx ECHO "No protected items to check for; aborting CheckProtFi."
    IF %ProtListFi%xxx==""xxx GOTO :EOF
    IF %ProtListFi%xxx==xxx ECHO "No protected items to check for; aborting CheckProtFi."
    IF %ProtListFi%xxx==xxx GOTO :EOF

	SET ProtListFi=%ProtListFi:"=%

REM This is where we virtually convert '\*' into ' ' for comparison
    FOR %%a in (%ProtListFi%) do (
        SET "CompFiItem=%%a"
        SET "ProtFiTmp=!CompFiItem:\*= !"
        SET "ChkFiTmp=Fi:!ChkFiItm!"
        IF /I "!ProtFiTmp!"=="!ChkFiTmp!" SET "ProtFiItm=TRUE"
    )

	Echo "ProtFiItm=%ProtFiItm%"

GOTO :EOF

:CHECKPROTFO
REM ECHO "Entering CHECKPROTFO"
    SET "ProtFoItm=FALSE"

    SET "WrkngDirFo=%1"
    IF %WrkngDirFo%xxx==""xxx ECHO "No directory passed to CheckProtFo, aborting procedure"
    IF %WrkngDirFo%xxx==""xxx GOTO :EOF
    IF %WrkngDirFo%xxx==xxx ECHO "No directory passed to CheckProtFo, aborting procedure"
    IF %WrkngDirFo%xxx==xxx GOTO :EOF

	SET WrkngDirFo=%WrkngDirFo:"=%

    IF NOT EXIST "%WrkngDirFo%" ECHO "Target directory, %WrkngDirFo%, not found. Aborting CheckProtFo"
    IF NOT EXIST "%WrkngDirFo%" GOTO :EOF

    SET "ChkFoItm=%2"
    IF %ChkFoItm%xxx==""xxx ECHO "No directory found to check, aborting CheckProtFo"
    IF %ChkFoItm%xxx==""xxx GOTO :EOF
    IF %ChkFoItm%xxx==xxx ECHO "No directory found to check, aborting CheckProtFo"
    IF %ChkFoItm%xxx==xxx GOTO :EOF

	SET ChkFoItm=%ChkFoItm:"=%

    SET "ProtListFo=%3"
    IF %ProtListFo%xxx==""xxx ECHO "No protected items to check for; aborting CheckProtFo."
    IF %ProtListFo%xxx==""xxx GOTO :EOF
    IF %ProtListFo%xxx==xxx ECHO "No protected items to check for; aborting CheckProtFo."
    IF %ProtListFo%xxx==xxx GOTO :EOF

	SET ProtListFo=%ProtListFo:"=%

    CD /D "%WrkngDirFo%"

REM This is where we virtually convert '\*' into ' ' for comparison
    FOR %%a in (%ProtlistFo%) do (
        SET "CompFoItem=%%a"
        SET "ProtFoTmp=!CompFoItem:\*= !"
        SET "ChkFoTmp=Fo:!ChkFoItm!"
        IF /I "!ProtFoTmp!"=="!ChkFoTmp!" SET "ProtFoItm=TRUE"
    )

	Echo "ProtFoItm=%ProtFoItm%"

GOTO :EOF

:PURGELOCALDCACHE
REM ECHO "Entering PURGELOCALDCACHE"

    IF NOT EXIST "%DBCACHE_PATH%collect\" ECHO "Required folder, %DBCACHE_PATH%\common\collect\, NOT found, aborting ServerDB Local Cache Cleanup"
    IF NOT EXIST "%DBCACHE_PATH%collect\" GOTO :EOF

    IF EXIST "%DBCACHE_PATH%master\" RD /S /Q "%DBCACHE_PATH%master\"
    IF EXIST "%DBCACHE_PATH%master\" ECHO "Failed to remove directory, %DBCACHE_PATH%master\. Will attempt to empty"
    IF NOT EXIST "%DBCACHE_PATH%master\" ECHO "Removed directory, %DBCACHE_PATH%master\ successfully"
    IF NOT EXIST "%DBCACHE_PATH%master\" GOTO :DELCACHEDIR

    SET "MyError=0"
        IF EXIST "%DBCACHE_PATH%master\" DEL "%DBCACHE_PATH%master\*.*" /F /S /Q
    SET "MyError=%Errorlevel%"
    IF "%MyError%"=="" SET "MyError=0"

    IF NOT %MyError% EQU 0 ECHO "Unable to delete or empty directory, aborting ServerDB Local Cache Cleanup"
    IF NOT %MyError% EQU 0 GOTO :EOF

:DELCACHEDIR
    IF NOT EXIST "%DBCACHE_PATH%master\" MD "%DBCACHE_PATH%master\"

    IF NOT EXIST "%DBCACHE_PATH%master\" ECHO "Failed to create folder, %DBCACHE_PATH%\master\, aborting ServerDB Local Cache Cleanup"
    IF NOT EXIST "%DBCACHE_PATH%master\" GOTO :EOF

    SET "MyError=0"
        Copy "%DBCACHE_PATH%collect\*.*" "%DBCACHE_PATH%master\" /Y /D
    SET "MyError=%Errorlevel%"
    IF "%MyError%"=="" SET "MyError=0"

    IF NOT %MyError% EQU 0 ECHO "Unable to reset ServerDB Local DB Cache. Cleanup failed"
    IF NOT %MyError% EQU 0 GOTO :EOF

    ECHO "LocalDB Cache Cleanup successful"

GOTO :EOF

:EXITNOW
REM ECHO "Entering Exit Process"

    IF /I "%AllowManualRestart%"=="True" CALL :STARTCAF

    SET "MSG=%1"
    IF %MSG%xxx==""xxx SET "MSG=none"
    IF %MSG%xxx==xxx SET "MSG=none"

	SET MSG=%MSG:"=%

    SET "CDE=%2"
    IF %CDE%xxx==""xxx SET "CDE=unnown"
    IF %CDE%xxx==xxx SET "CDE=unnown"

	SET CDE=%CDE:"=%

ECHO "Process has returned exit code %CDE%, and message %MSG%. Will now exit"

ECHO "Execution complete at %time% on %date%"

ENDLOCAL

Exit %CDE%

GOTO :EOF

:COUNTLOGS
REM ECHO "Entering COUNTLOGS"

    IF NOT EXIST "%CLIENT_LOG_PATH%" ECHO "Specified path, %CLIENT_LOG_PATH%, not found"
    IF NOT EXIST "%CLIENT_LOG_PATH%" GOTO :EOF

    CD /D "%CLIENT_LOG_PATH%"

    FOR /f "tokens=1* delims= " %%a in ('dir "%Searchname%" ^| findstr /i "/c:file(s)"') do (
        SET "LogNum=%%a"
    )

    IF "%LogNum%"=="" SET "LogNum=0"

ECHO "There are %LogNum% log files in %CLIENT_LOG_PATH%"

GOTO :EOF

:TRIMLOGS
REM ECHO "Entering TRIMLOGS"
    SET "Curfile=nothing"
    SET "FoundLast=FALSE"
    SET "NoMore=FALSE"
    SET "LastLog=nothing"

    IF NOT EXIST "%CLIENT_LOG_PATH%" ECHO "Specified path, %CLIENT_LOG_PATH%, not found"
    IF NOT EXIST "%CLIENT_LOG_PATH%" GOTO :EOF

    CD /D "%CLIENT_LOG_PATH%"

REM We want to be left with one LESS than the maximum number of logs
REM Thus the -1 below.
    SET /a Trimnum=(%LogNum%-%MaxLogs%)+1

    IF %TRIMNUM% LSS 0 SET "TRIMNUM=0"
    ECHO "Will remove %Trimnum% files from log folder"
    SET "CurThere=FALSE"
    SET "CurGone=FALSE"
    SET "CanDel=FALSE"
    SET "CurNum=0"
    SET "FoundLast=FALSE"
    SET "NoMore=FALSE"
    FOR /f %%a in ('dir "%SearchName%" /O:D /T:W /b') do (
        SET "CurFile=%%a"
        IF EXIST "!Curfile!" SET "CurThere=TRUE"
        IF EXIST "!Curfile!" SET /a CurNum=CurNum+1
        IF !CurNum! LEQ %TrimNum% SET "CanDel=TRUE"
        IF !CurNum! GTR %TrimNum% SET "CanDel=FALSE"
        IF /I "!CurThere!!CanDel!"=="TrueTrue" DEL /F /Q "!Curfile!"
        IF EXIST "!Curfile!" SET "CurGone=FALSE"
        IF NOT EXIST "!Curfile!" SET "CurGone=TRUE"
        IF /I "!CurThere!!CanDel!!CurGone!"=="TrueTrueTrue" ECHO "Deletion of !Curfile! completed successfully"
        IF /I "!CurThere!!CanDel!!CurGone!"=="TrueTrueFalse" ECHO "Deletion of !Curfile! from %CLIENT_LOG_PATH% has failed"
        IF !CurNum! GTR %TrimNum% SET "FoundLast=TRUE"
        IF /I "!FoundLast!!NoMore!"=="TrueFalse" SET "LastLog=!CurFile!"
        IF /I "!FoundLast!"=="True" SET "NoMore=TRUE"
    )

ECHO "Oldest logs have been trimmed"
ECHO "The oldest log to remain will be %LastLog%"

GOTO :EOF

:OLDESTLOG
REM ECHO "Entering OLDESTLOG"
    SET "OldFile=nothing"

    IF NOT EXIST "%CLIENT_LOG_PATH%" ECHO "Specified path, %CLIENT_LOG_PATH%, not found, exiting OldestLog"
    IF NOT EXIST "%CLIENT_LOG_PATH%" GOTO :EOF

    CD /D "%CLIENT_LOG_PATH%"

    SET "Ronce=0"
    FOR /f %%a in ('dir "%searchname%" /A:-D /O:D /T:W /B') do (
        SET /a ronce=ronce+1
        IF !Ronce! EQU 1 SET "OldFile=%%a"
    )
    SET "Oldstlg=%OldFile%"
ECHO "The oldest log file is %Oldstlg%"

GOTO :EOF

:RETAINFOLDER
REM ECHO "Entering RETAINFOLDER"
    SET "CurFoMaxAge=%1"
    SET "FolderToCheck=%2"
	SET "RTFolderDir=%3"
	SET "KeepFold=TRUE"
	SET "KeepFoSecs=-1"

    IF %CurFoMaxAge%xxx==""xxx ECHO "No max age provided, aborting procedure"
    IF %CurFoMaxAge%xxx==""xxx GOTO :EOF
    IF %CurFoMaxAge%xxx==xxx ECHO "No max age provided, aborting procedure"
    IF %CurFoMaxAge%xxx==xxx GOTO :EOF

	SET CurFoMaxAge=%CurFoMaxAge:"=%

    IF %FolderToCheck%xxx==""xxx ECHO "RETAINFOLDER was called without specifying a valid file name to check; aborting"
    IF %FolderToCheck%xxx==""xxx GOTO :EOF
    IF %FolderToCheck%xxx==xxx ECHO "RETAINFOLDER was called without specifying a valid file name to check; aborting"
    IF %FolderToCheck%xxx==xxx GOTO :EOF

	SET FolderToCheck=%FolderToCheck:"=%

    IF %RTFolderDir%xxx==""xxx ECHO "RETAINFOLDER was called without specifying a valid directory to work in; aborting"
    IF %RTFolderDir%xxx==""xxx GOTO :EOF
    IF %RTFolderDir%xxx==xxx ECHO "RETAINFOLDER was called without specifying a valid directory to work in; aborting"
    IF %RTFolderDir%xxx==xxx GOTO :EOF

	SET RTFolderDir=%RTFolderDir:"=%
	
	IF NOT EXIST "%RTFolderDir%" ECHO "Folder, %RTFolderDir%, no longer exists, will not attempt to remove"
	IF NOT EXIST "%RTFolderDir%" GOTO :EOF
	
	CD /D "%RTFolderDir%"

	IF NOT EXIST "%FolderToCheck%" ECHO "Folder, %FolderToCheck%, no longer exists, will not proceed"
	IF NOT EXIST "%FolderToCheck%" GOTO :EOF

	IF %CurFoMaxAge% EQU 0 SET "KeepFold=FALSE"
	IF %CurFoMaxAge% EQU 0 GOTO :EOF
	
    CALL :CALCOLDESTITEM %CurFoMaxAge%
    SET "KeepFoSecs=%OldestItemSecs%"
    ECHO "File age must be greater than %KeepFoSecs% from key date to keep"
	
    CALL :CURAGEFOLD "%RTFolderDir%" "%FolderToCheck%"
    SET "RTFoldAge=%TotFoAgeSecs%"
    ECHO "Folder age is %RTFoldAge% seconds from key date and keep secs is %KeepFoSecs%"

    IF %RTFoldAge% LEQ %KeepFoSecs% SET "KeepFold=FALSE"
    IF %RTFoldAge% GTR %KeepFoSecs% SET "KeepFold=TRUE"
	IF %RTFoldAge% EQU -1 SET "KeepFold=TRUE"
	
	ECHO "KeepFold value for '%FolderToCheck%' is %KeepFold%"

GOTO :EOF

:RETAINFILE
REM ECHO "Entering RETAINFILE"
    SET "CurMaxAge=%1"
    SET "FileToCheck=%2"
    SET "RTFFileDir=%3"
    SET "KeepFile=TRUE"
	SET "KeepSecs=-1"

    IF %CurMaxAge%xxx==""xxx ECHO "No max age provided, aborting procedure"
    IF %CurMaxAge%xxx==""xxx GOTO :EOF
    IF %CurMaxAge%xxx==xxx ECHO "No max age provided, aborting procedure"
    IF %CurMaxAge%xxx==xxx GOTO :EOF

	SET CurMaxAge=%CurMaxAge:"=%

    IF %FileToCheck%xxx==""xxx ECHO "RetainFile was called without specifying a valid file name to check; aborting"
    IF %FileToCheck%xxx==""xxx GOTO :EOF
    IF %FileToCheck%xxx==xxx ECHO "RetainFile was called without specifying a valid file name to check; aborting"
    IF %FileToCheck%xxx==xxx GOTO :EOF

	SET FileToCheck=%FileToCheck:"=%
    
    IF %RTFFileDir%xxx==""xxx ECHO "RetainFile was called without specifying a valid directory to check; aborting"
    IF %RTFFileDir%xxx==""xxx GOTO :EOF
    IF %RTFFileDir%xxx==xxx ECHO "RetainFile was called without specifying a valid directory to check; aborting"
    IF %RTFFileDir%xxx==xxx GOTO :EOF

	SET RTFFileDir=%RTFFileDir:"=%

    IF NOT EXIST "%RTFFileDir%" ECHO "RetainFile was called without specifying a valid directory to check; aborting"
    IF NOT EXIST "%RTFFileDir%" GOTO :EOF

    CD /D "%RTFFileDir%"

    IF NOT EXIST "%FileToCheck%" ECHO "RetainFile was called without specifying a valid file name to check; aborting"
    IF NOT EXIST "%FileToCheck%" GOTO :EOF

    IF %CurMaxAge% EQU 0 SET "KeepFile=FALSE"
    IF %CurMaxAge% EQU 0 GOTO :EOF

    CALL :CALCOLDESTITEM %CurMaxAge%
    SET "KeepSecs=%OldestItemSecs%"
    ECHO "File age must be greater than %KeepSecs% from key date to keep"

    CALL :CURAGEFILE "%RTFFileDir%" "%FileToCheck%"
    SET "RTFFileAge=%TotAgeSecs%"
    ECHO "File is actually %RTFFileAge% seconds from key date"

    IF %RTFFileAge% LEQ %KeepSecs% SET "KeepFile=FALSE"
    IF %RTFFileAge% GTR %KeepSecs% SET "KeepFile=TRUE"
	IF %RTFFileAge% EQU -1 SET "KeepFile=TRUE"
	
	ECHO "KeepFile value for %FileToCheck% is %KeepFile%"

GOTO :EOF

:CALCOLDESTITEM
REM ECHO "Entering CALCOLDESTITEM"
    SET "FiExpAge=%1"
    SET "OldestItemSecs=0"
    SET "SecsTilNow=0"
    SET "SecsToday=0"

    IF %FiExpAge%xxx==""xxx ECHO "No max age provided, aborting procedure"
    IF %FiExpAge%xxx==""xxx GOTO :EOF
    IF %FiExpAge%xxx==xxx ECHO "No max age provided, aborting procedure"
    IF %FiExpAge%xxx==xxx GOTO :EOF

	SET FiExpAge=%FiExpAge:"=%

    CALL :GETNOWSECS
        SET /a SecsTilNow=%GNSTotSecs%

REM Max File Age in Seconds
    CALL :DAYSTOSECS %FiExpAge%
        SET /a ExpireSecs=%DSecs%
		ECHO "Expiration Limit Seconds = %ExpireSecs%"

REM Oldest file kept should be
    SET /a OldestItemSecs=%SecsTilNow%-%ExpireSecs%
	ECHO "Oldest file to keep should be %SecsTilNow%-%ExpireSecs% or %OldestItemSecs%"

GOTO :EOF

:CURAGEFOLD
REM ECHO "Entering CURAGEFOLD"
    SET "WorkFolder=%1"
    SET "FoldToChk=%2"
	SET "TotFoAgeSecs=-1"

    IF %WorkFolder%xxx==""xxx ECHO "Required parameter, Work Folder, not passed to function; aborting."
    IF %WorkFolder%xxx==""xxx GOTO :EOF
    IF %WorkFolder%xxx==xxx ECHO "Required parameter, Work Folder, not passed to function; aborting."
    IF %WorkFolder%xxx==xxx GOTO :EOF

	SET WorkFolder=%WorkFolder:"=%

    IF %FoldToChk%xxx==""xxx ECHO "Required parameter, Folder name, not passed to function; aborting."
    IF %FoldToChk%xxx==""xxx GOTO :EOF
    IF %FoldToChk%xxx==xxx ECHO "Required parameter, Folder name, not passed to function; aborting."
    IF %FoldToChk%xxx==xxx GOTO :EOF

	SET FoldToChk=%FoldToChk:"=%

    IF NOT EXIST "%WorkFolder%" ECHO "Provided directory, %WorkFolder%, does not exist; aborting"
    IF NOT EXIST "%WorkFolder%" GOTO :EOF

    CD /D "%WorkFolder%"

    IF NOT EXIST "%FoldToChk%" ECHO "Provided file name, %FoldToChk%, does not exist; aborting"
    IF NOT EXIST "%FoldToChk%" GOTO :EOF

    For /F "Tokens=1-4* Delims= " %%a in ('dir /A:D /O:D /T:C ^| findstr /I /C:"%FoldToChk%"') do (
        SET "FullFoDate=%%a"
        SET "FullFoTime=%%b"
        SET "FoAMPM=%%c"
    )

    IF "%FullFoDate%"=="" ECHO "Failed to read date; exiting procedure"
    IF "%FullFoDate%"=="" GOTO :EOF
    IF "%FullFoTime%"=="" ECHO "Failed to read time; exiting procedure"
    IF "%FullFoTime%"=="" GOTO :EOF
    IF "%FoAMPM%"=="" ECHO "Failed to read AM or PM, will assume AM as the impact is minimal"
    IF "%FoAMPM%"=="" SET "FoAMPM=AM"

    SET "CAFoYear=%FullFoDate:~-4%"
    SET "FoMthDy=%FullFoDate:~,-5%"
    SET "CAFoDays=%FoMthDy:~-2%"
    SET "CAFoMth=%FoMthDy:~,-3%"

    IF "%CAFoMth:~,1%"=="0" SET "CAFoMth=%CAFoMth:~1%"
    IF "%CAFoDays:~,1%"=="0" SET "CAFoDays=%CAFoDays:~1%"

    SET "FoMinutes=%FullFoTime:~-2%"
    SET "FoHours=%FullFoTime:~0,-3%"

	IF "%FoMinutes%"=="" SET /a FoMinutes=0
	IF "%FoMinutes:~0,1%"=="0" SET FoMinutes=%FoMinutes:~1%
	IF "%FoMinutes%"=="" SET /a FoMinutes=0

	IF "%FoHours%"=="" SET /a FoHours=0
	IF "%FoHours:~0,1%"=="0" SET FoHours=%FoHours:~1%
	IF "%FoHours%"=="" SET /a FoHours=0

    SET /a FoHourMins=%FoHours%*60
    SET /a AllFoMins=%FoHourMins%+%FoMinutes%

    SET /a FoTimeSecs=%AllFoMins%*60

    CALL :YEARTODAYS %CAFoYear%
        SET "FoYearDays=%YDays%"
    CALL :MONTHOFYEARTODAYS %CAFoYear% %CAFoMth%
        SET "FoMonthDays=%MDays%"

	IF "%FoYearDays%"=="" SET /a FoYearDays=0
	IF "%FoYearDays:~0,1%"=="0" SET FoYearDays=%FoYearDays:~1%
	IF "%FoYearDays%"=="" SET /a FoYearDays=0

	IF "%FoMonthDays%"=="" SET /a FoMonthDays=0
	IF "%FoMonthDays:~0,1%"=="0" SET FoMonthDays=%FoMonthDays:~1%
	IF "%FoMonthDays%"=="" SET /a FoMonthDays=0

    SET /a FoAllDays=%FoYearDays%+%FoMonthDays%+%CAFoDays%

    CALL :DAYSTOSECS %FoAllDays%
        SET "FoDaySecs=%DSecs%"

	IF "%FoDaySecs%"=="" SET /a FoDaySecs=0
	IF "%FoDaySecs:~0,1%"=="0" SET FoDaySecs=%FoDaySecs:~1%
	IF "%FoDaySecs%"=="" SET /a FoDaySecs=0

	IF "%FoTimeSecs%"=="" SET /a FoTimeSecs=0
	IF "%FoTimeSecs:~0,1%"=="0" SET FoTimeSecs=%FoTimeSecs:~1%
	IF "%FoTimeSecs%"=="" SET /a FoTimeSecs=0

        SET /a TotFoAgeSecs=%FoDaySecs%+%FoTimeSecs%

GOTO :EOF

:CURAGEFILE
REM ECHO "Entering CURAGEFILE"
    SET "FileDir=%1"
    SET "FileName=%2"
	SET TotAgeSecs=-1

    IF %FileDir%xxx==""xxx ECHO "Required parameter, File Directory, not passed to function; aborting."
    IF %FileDir%xxx==""xxx GOTO :EOF
    IF %FileDir%xxx==xxx ECHO "Required parameter, File Directory, not passed to function; aborting."
    IF %FileDir%xxx==xxx GOTO :EOF

	SET FileDir=%FileDir:"=%

    IF %FileName%xxx==""xxx ECHO "Required parameter, File name, not passed to function; aborting."
    IF %FileName%xxx==""xxx GOTO :EOF
    IF %FileName%xxx==xxx ECHO "Required parameter, File name, not passed to function; aborting."
    IF %FileName%xxx==xxx GOTO :EOF

	SET FileName=%FileName:"=%

    IF NOT EXIST "%FileDir%" ECHO "Provided directory, %FileDir%, does not exist; aborting"
    IF NOT EXIST "%FileDir%" GOTO :EOF

    CD /D "%FileDir%"

    IF NOT EXIST "%FileName%" ECHO "Provided file name, %FileName%, does not exist; aborting"
    IF NOT EXIST "%FileName%" GOTO :EOF

    For /F "Tokens=1-4* Delims= " %%a in ('dir /A:-D /O:D /T:W ^| findstr /I /C:"%FileName%"') do (
        SET "FullDate=%%a"
        SET "FullTime=%%b"
        SET "AMPM=%%c"
    )

    IF "%FullDate%"=="" ECHO "Failed to read date; exiting procedure"
    IF "%FullDate%"=="" GOTO :EOF
    IF "%FullTime%"=="" ECHO "Failed to read time; exiting procedure"
    IF "%FullTime%"=="" GOTO :EOF
    IF "%AMPM%"=="" ECHO "Failed to read AM or PM, will assume AM as the impact is minimal"
    IF "%AMPM%"=="" SET "AMPM=AM"

    SET "CAFYear=%FullDate:~-4%"
    SET "MthDy=%FullDate:~,-5%"
    SET "CAFDays=%MthDy:~-2%"
    SET "CAFMth=%MthDy:~,-3%"

    IF "%CAFMth:~,1%"=="0" SET "CAFMth=%CAFMth:~1%"
    IF "%CAFDays:~,1%"=="0" SET "CAFDays=%CAFDays:~1%"

    SET "Minutes=%FullTime:~-2%"
    SET "Hours=%FullTime:~0,-3%"

	IF "%Minutes%"=="" SET /a Minutes=0
	IF "%Minutes:~0,1%"=="0" SET Minutes=%Minutes:~1%
	IF "%Minutes%"=="" SET /a Minutes=0

	IF "%Hours%"=="" SET /a Hours=0
	IF "%Hours:~0,1%"=="0" SET Hours=%Hours:~1%
	IF "%Hours%"=="" SET /a Hours=0

    SET /a HourMins=%Hours%*60
    SET /a AllMins=%HourMins%+%Minutes%

    SET /a TimeSecs=%AllMins%*60

    CALL :YEARTODAYS %CAFYear%
        SET "YearDays=%YDays%"
    CALL :MONTHOFYEARTODAYS %CAFYear% %CAFMth%
        SET "MonthDays=%MDays%"

	IF "%YearDays%"=="" SET /a YearDays=0
	IF "%YearDays:~0,1%"=="0" SET YearDays=%YearDays:~1%
	IF "%YearDays%"=="" SET /a YearDays=0

	IF "%MonthDays%"=="" SET /a MonthDays=0
	IF "%MonthDays:~0,1%"=="0" SET MonthDays=%MonthDays:~1%
	IF "%MonthDays%"=="" SET /a MonthDays=0

    SET /a AllDays=%YearDays%+%MonthDays%+%CAFDays%

    CALL :DAYSTOSECS %AllDays%
        SET "DaySecs=%DSecs%"

	IF "%DaySecs%"=="" SET /a DaySecs=0
	IF "%DaySecs:~0,1%"=="0" SET DaySecs=%DaySecs:~1%
	IF "%DaySecs%"=="" SET /a DaySecs=0

	IF "%TimeSecs%"=="" SET /a TimeSecs=0
	IF "%TimeSecs:~0,1%"=="0" SET TimeSecs=%TimeSecs:~1%
	IF "%TimeSecs%"=="" SET /a TimeSecs=0

        SET /a TotAgeSecs=%DaySecs%+%TimeSecs%

GOTO :EOF

:YEARTODAYS
REM ECHO "Entering YEARTODAYS"
REM Procedure expects to be sent a year value to function
REM Converts to a year value minus 1971 automatically to avoid 32-bit number limitations.
    SET "YTDYear=%1"
    IF %YTDYear%xxx==""xxx ECHO "Year to days function requires a year which was not provided. Aborting procedure"
    IF %YTDYear%xxx==""xxx GOTO :EOF
    IF %YTDYear%xxx==xxx ECHO "Year to days function requires a year which was not provided. Aborting procedure"
    IF %YTDYear%xxx==xxx GOTO :EOF

	SET YTDYear=%YTDYear:"=%

    SET "CntYear=0"

    IF %YTDYear% LEQ 1971 ECHO "An invalid year, %YTDYear% was read. Calculations will be invalid"
    IF %YTDYear% GTR 1971 SET /a CntYear=%YTDYear%-1971

    SET "YDays=0"
    SET "Leaps=0"

    SET /a Leaps=(((%CntYear%+1971)/4)-(1971/4))
    SET /a Ydays=(%CntYear%*365)+(%Leaps%)

REM ECHO "The year %YTDYear%, is %CntYear% years after 1971 and %leaps% leap years have occurred during that time."
REM ECHO "So the total number of days that have passed since 1-1-1971 is %yDays%."

GOTO :EOF

:MONTHOFYEARTODAYS
REM ECHO "Entering MONTHOFYEARTODAYS"
    SET "MOYYear=%1"
    IF %MOYYear%xxx==""xxx ECHO "Month of year to days function requires a year which was not provided. Aborting procedure"
    IF %MOYYear%xxx==""xxx GOTO :EOF
    IF %MOYYear%xxx==xxx ECHO "Month of year to days function requires a year which was not provided. Aborting procedure"
    IF %MOYYear%xxx==xxx GOTO :EOF

	SET MOYYear=%MOYYear:"=%

    SET "MOYMonths=%2"
    IF %MOYMonths%xxx==""xxx ECHO "Month of year to days function requires a numerical month which was not provided. Aborting procedure"
    IF %MOYMonths%xxx==""xxx GOTO :EOF
    IF %MOYMonths%xxx==xxx ECHO "Month of year to days function requires a numerical month which was not provided. Aborting procedure"
    IF %MOYMonths%xxx==xxx GOTO :EOF

	SET MOYMonths=%MOYMonths:"=%

    SET "MOYDays=0"
    SET "Mdays=0"
    SET "CntYear=0"

    IF %MOYYear% LEQ 1971 ECHO "An invalid year, %MOYYear% was sent to MonthOfYearToDays function. Calculations will be invalid"

REM NOTE: due to lack of day data here, when run on Feb 29th
REM E.G. the last day of February on a leap year, the calculation
REM Will be off by one day as we cannot tell IF we are on the exact
REM day of February 29th. However year conversions will include leap years.
    SET "Leap=FALSE"

REM IF it is a leap year in general then set variable to True
    SET /a LeapTest=99
    SET /a LeapTest=%MOYYear% %% 4
    IF %Leaptest% EQU 0 SET "Leap=TRUE"

REM If it is not at least March 1st then we do NOT have the extra day
REM to add into our calculations.
    IF %MOYMonths% LEQ 2 SET "Leap=FALSE"

    SET "Jan=31"
    SET "Feb=28"
    SET "Mar=31"
    SET "Apr=30"
    SET "May=31"
    SET "Jun=30"
    SET "Jul=31"
    SET "Aug=31"
    SET "Sep=30"
    SET "Oct=31"
    SET "Nov=30"
    SET "Dec=31"

    IF %MOYMonths% GTR 12 ECHO "Invalid month, %MOYMonths%, specified, aborting subroutine"
    IF %MOYMonths% GTR 12 GOTO :EOF

    IF %MOYMonths% LSS 0 ECHO "Month value provided, %MOYMonths%, is invalid. Aborting subroutine"
    IF %MOYMonths% LSS 0 GOTO :EOF

REM To calculate days from months we must assume a starting point of January
REM We must also calculate IF it is a leap year or NOT IF months has a value or 2 or greater
REM We must finally set a reference array to identify the total days in each month

    IF %MOYMonths% EQU 1 SET /a Mdays=0
    IF %MOYMonths% EQU 2 SET /a Mdays=%Jan%
    IF %MOYMonths% EQU 3 SET /a Mdays=%Jan%+%Feb%
    IF %MOYMonths% EQU 4 SET /a Mdays=%Jan%+%Feb%+%Mar%
    IF %MOYMonths% EQU 5 SET /a Mdays=%Jan%+%Feb%+%Mar%+%Apr%
    IF %MOYMonths% EQU 6 SET /a Mdays=%Jan%+%Feb%+%Mar%+%Apr%+%May%
    IF %MOYMonths% EQU 7 SET /a Mdays=%Jan%+%Feb%+%Mar%+%Apr%+%May%+%Jun%
    IF %MOYMonths% EQU 8 SET /a Mdays=%Jan%+%Feb%+%Mar%+%Apr%+%May%+%Jun%+%Jul%
    IF %MOYMonths% EQU 9 SET /a Mdays=%Jan%+%Feb%+%Mar%+%Apr%+%May%+%Jun%+%Jul%+%Aug%
    IF %MOYMonths% EQU 10 SET /a Mdays=%Jan%+%Feb%+%Mar%+%Apr%+%May%+%Jun%+%Jul%+%Aug%+%Sep%
    IF %MOYMonths% EQU 11 SET /a Mdays=%Jan%+%Feb%+%Mar%+%Apr%+%May%+%Jun%+%Jul%+%Aug%+%Sep%+%Oct%
    IF %MOYMonths% EQU 12 SET /a Mdays=%Jan%+%Feb%+%Mar%+%Apr%+%May%+%Jun%+%Jul%+%Aug%+%Sep%+%Oct%+%Nov%

    IF /I "%Leap%"=="True" SET /a Mdays=%Mdays%+1

GOTO :EOF

:DAYSTOSECS
REM ECHO "Entering DAYSTOSECS"
    SET /a dsecs=0
    SET "DTSDays=%1"

    IF %DTSDays%xxx==""xxx ECHO "Day to Second conversion called without specifying a day value, aborting procedure"
    IF %DTSDays%xxx==""xxx GOTO :EOF
    IF %DTSDays%xxx==xxx ECHO "Day to Second conversion called without specifying a day value, aborting procedure"
    IF %DTSDays%xxx==xxx GOTO :EOF

	SET DTSDays=%DTSDays:"=%

    IF %DTSDAYS% LSS 0 ECHO "Invalid number of days, %DTSDAYS%, was passed to procedure. Aborting."
    IF %DTSDAYS% LSS 0 GOTO :EOF

REM First we convert days into hours
    SET /a DSecs=%DTSDays%*24

REM Then we convert hours into minutes
    SET /a DSecs=%Dsecs%*60

REM Finally we convert minutes into seconds
    SET /a Dsecs=%Dsecs%*60

GOTO :EOF

:GETNOWSECS
REM ECHO "Entering GETNOWSECS"
    SET "GNSTotSecs=0"
    SET "GNSYear=0"
    SET "GNSDay=0"
    SET "GNSMonth=0"

    FOR /F "Tokens=1-4* delims=/ " %%a in ('ECHO %Date%') do (
        SET "GNSMonth=%%b"
        SET "GNSDay=%%c"
        SET "GNSYear=%%d"
    )

    IF "%GNSMonth%"=="" SET /a GNSMonth=0
    IF "%GNSMonth:~0,1%"=="0" SET "GNSMonth=%GNSMonth:~1%"
    IF "%GNSMonth%"=="" SET /a GNSMonth=0

    IF "%GNSDay%"=="0" SET /a GNSDay=0"
    IF "%GNSDay:~0,1%"=="0" SET "GNSDay=%GNSDay:~1%"
    IF "%GNSDay%"=="0" SET /a GNSDay=0"

    IF "%GNSYear%"=="0" SET /a GNSYear=0"
    IF "%GNSYear:~0,1%"=="0" SET "GNSYear=%GNSYear:~1%"
    IF "%GNSYear%"=="0" SET /a GNSYear=0"

    IF "%GNSYear%"=="" ECHO "Invalid date returned, aborting procedure"
    IF "%GNSYear%"=="" GOTO :EOF

    IF %GNSYear% LEQ 1971 ECHO "An invalid Year, %GNSYear%, was detected, aborting procedure"
    IF %GNSYear% LEQ 1971 GOTO :EOF

    IF "%GNSMonth%"=="" ECHO "No month returned, aborting procedure"
    IF "%GNSMonth%"=="" GOTO :EOF

    IF %GNSMonth% LEQ 0 ECHO "An invalid month, %GNSMonth%, was detected, aborting procedure"
    IF %GNSMonth% LEQ 0 GOTO :EOF

    IF "%GNSDay%"=="" ECHO "No day returned, aborting procedure"
    IF "%GNSDay%"=="" GOTO :EOF

    IF %GNSDay% LEQ 0 ECHO "An invalid day of month, %GNSDay%, was detected, aborting procedure"
    IF %GNSDay% LEQ 0 GOTO :EOF

    CALL :YEARTODAYS %GNSYear%

    IF "%YDays%"=="" SET /a YDays=0
    IF "%YDays:~0,1%"=="0" SET "YDays=%YDays:~1%"
    IF "%YDays%"=="" SET /a YDays=0

    SET "GNSTotdays=%YDays%"

    CALL :MONTHOFYEARTODAYS %GNSYear% %GNSMonth%

    IF "%MDays%"=="" SET /a MDays=0
    IF "%MDays:~0,1%"=="0" SET "MDays=%MDays:~1%"
    IF "%MDays%"=="" SET /a MDays=0

    SET /a GNSTotdays=%GNSTotdays%+%MDays%

    SET /a GNSTotdays=%GNSTotdays%+%GNSDay%

REM ECHO "Converting the total number of days, %GNSTotdays%, into seconds"
    SET /a DSecs=0
        IF %GNSTotdays% LEQ 0 SET /a GNSTotdays=0
        IF %GNSTotdays% GTR 0 CALL :DAYSTOSECS %GNSTotdays%

    IF "%Dsecs%"=="" SET /a Dsecs=0
    IF "%Dsecs:~0,1%"=="0" SET "Dsecs=%Dsecs:~1%"
    IF "%Dsecs%"=="" SET /a Dsecs=0

    SET /a GNSTotSecs=%Dsecs%

    CALL :GETSECS

    IF "%FNUM%"=="" SET /a FNUM=0
    IF "%FNUM:~0,1%"=="0" SET "FNUM=%FNUM:~1%"
    IF "%FNUM%"=="" SET /a FNUM=0

    SET /a GNSTotSecs=%GNSTotSecs%+%FNUM%

REM ECHO "Returning total seconds in current time and date as %GNSTotSecs%"

GOTO :EOF

:GETSECS
REM ECHO "Entering GETSECS"
    SET /a FNUM=0
	SET /a HH=0
	SET /a MM=0
	SET /a SS=0

    FOR /F "tokens=1-3* delims=:." %%a in ("%TIME%") do (
        SET "HH=%%a"
        SET "HH=!HH: =!"
            IF "!HH:~0,1!"=="0" SET "HH=!HH:~1!"
            IF "!HH!"=="" SET /a HH=0
        SET "MM=%%b"
        SET "MM=!MM: =!"
            IF "!MM:~0,1!"=="0" SET "MM=!MM:~1!"
            IF "!MM!"=="" SET /a MM=0
        SET "SS=%%c"
        SET "SS=!SS: =!"
            IF "!SS:~0,1!"=="0" SET "SS=!SS:~1!"
            IF "!SS!"=="" SET /a SS=0
    )

    SET /a FS=%SS%
    SET /a FM=%MM%*60
    SET /a FH=%HH%*60*60

    SET /a FNUM=%FH%+%FM%+%FS%

GOTO :EOF

:WAITXSECS
REM ECHO "Entering WAITXSECS"
REM Will wait FOR passed number of seconds and then return to script
    SET "Timer=%1"

    IF %Timer%xxx==""xxx ECHO "Procedure invoked without specifying time to wait. Exiting WaitXSecs"
    IF %Timer%xxx==""xxx GOTO :EOF
    IF %Timer%xxx==xxx ECHO "Procedure invoked without specifying time to wait. Exiting WaitXSecs"
    IF %Timer%xxx==xxx GOTO :EOF

	SET Timer=%Timer:"=%

    IF %TIMER% LEQ 0 ECHO "Procedure invoked without specifying valid time to wait. Exiting WaitXSecs"
    IF %TIMER% LEQ 0 GOTO :EOF

    SET "GottaWrap=FALSE"
    SET /a StartTime=0
    SET /a EndTime=0

REM 86,400 will never be reached...that would be 0:00:00 or midnight...
    SET /a MaxCount=(23*60*60)+(59*60)+(59)

    CALL :GETSECS

    SET "StartTime=%Fnum%"
    SET /a EndTime=%StartTime%+%Timer%

ECHO "Start Time is %StartTime%, Timer is %Timer%, and end time is %EndTime%"

    IF %EndTime% GEQ %MaxCount% SET "GottaWrap=TRUE"
    IF %EndTime% GEQ %MaxCount% SET /a StartTime=%StartTime%-%MaxCount%
    IF %EndTime% GEQ %MaxCount% SET /a EndTime=%EndTime%-%MaxCount%

:COUNTNOW

    CALL :GETSECS

    IF "%FNUM%"=="" SET /a FNUM=0
    IF "%FNUM:~0,1%"=="0" SET "FNUM=%FNUM:~1%"
    IF "%FNUM%"=="" SET /a FNUM=0

    IF /I "%GottaWrap%"=="True" SET /a FNUM=!FNUM!-%MaxCount%
    IF !FNUM! GEQ %EndTime% ECHO "Finished Waiting %Timer% seconds."
    IF !FNUM! GEQ %EndTime% GOTO :DONECOUNTIN

GOTO :COUNTNOW

:DONECOUNTIN

GOTO :EOF

:CLEANANON

	Set ListCMD=%CertUtilCmd% list -v
	
	Set MyError=0
		%ListCMD% >nul
	Set MyError=%Errorlevel%
	If "%MyError%"=="" Set MyError=0
	If not %MyError%==0 Echo "Certutility list test failed, skipping anonymous cleanup."
	If not %MyError%==0 goto :EOF
	
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

GOTO :EOF
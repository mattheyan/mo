@ECHO OFF

SETLOCAL enableExtensions enableDelayedExpansion

SET argCount=0
FOR %%x IN (%*) DO (
   SET /A argCount+=1
   SET "argVec[!argCount!]=%%~x"
)

set argString=

FOR /L %%i IN (1,1,%argCount%) DO (
    :: Add space if needed
    if not "x!argString!"=="x" ( set argString=!argString! )

    :: Check for spaces and surround in double quotes if needed
    if not "x!argVec[%%i]: =!"=="x!argVec[%%i]!" (
        set argString=!argString!\"!argVec[%%i]!\"
    ) else (
        set argString=!argString!!argVec[%%i]!
    )
)

:: Set a random value to signal that changes to the PSModulePath will not be seen by this process
SET PSModulePathProcessID=%RANDOM%

@powershell -NoProfile -ExecutionPolicy Bypass -Command "ipmo ~\Workspace\mo\Mo.psd1 ; Invoke-MoCommand !argstring!"

ENDLOCAL

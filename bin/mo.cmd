@echo OFF

REM Get the name of the file, without the file extension.
REM http://stackoverflow.com/a/3215539
SET name=%~n0

REM Get the path to the folder that the script resides in, w/o the trailing '\'.
SET bin=%~dp0
REM http://ss64.com/nt/syntax-substring.html
SET bin=%bin:~0,-1%

REM Get the root folder path
SET root=%bin:~0,-4%

REM Get the content of 'version.txt'.
REM http://stackoverflow.com/q/14834625
FOR /F %%i IN (%bin%\version.txt) DO SET version=%%i

REM Get the name of the command as the first argument, or 'help' if missing.
SET command=%1
REM http://stackoverflow.com/a/2541820
IF [%1] == [] SET command=help

REM Get remaining arguments following the command.
REM http://stackoverflow.com/questions/935609/batch-parameters-everything-after-1
for /f "tokens=1,* delims= " %%a in ("%*") do set args=%%b

REM Find the PowerShell module in the root directory.
REM http://stackoverflow.com/a/16575196
REM http://ss64.com/nt/for2.html
REM http://stackoverflow.com/a/18464353
for %%f in (%root%\%name%.psd1) do set module=%%f
IF [%module%] == [] (
    for %%f in (%root%\%name%.psm1) do SET module=%%f
    IF [%module%] == [] (
        REM Fall back to load a 'psm1' file module with any name.
        for %%f in (%root%\*.psm1) do set module=%%f
    )
)

REM Write the program name and version at the start of each command.
echo %name% v%version%

REM Add the 'Modules' directory to 'PSModulePath' so that required modules can be loaded.
SET PSModulePath=%root%\Modules;%PSModulePath%

REM Load the PowerShell module and execute the command script.
@powershell -ExecutionPolicy Bypass -NoProfile -Command "ipmo '%module%'; & '%root%\Commands\%command%.ps1' %args%"

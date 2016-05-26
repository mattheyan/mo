@echo OFF
REM http://stackoverflow.com/questions/935609/batch-parameters-everything-after-1
for /f "tokens=1,* delims= " %%a in ("%*") do set args=%%b
@powershell -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0\..\Commands\%1.ps1' %args%"

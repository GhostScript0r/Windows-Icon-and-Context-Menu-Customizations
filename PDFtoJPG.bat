@echo off
set /a PAGE=0
set FILENAME=%~n1
set /a MAXPAGE=%2
:CONVERTPAGE0TO9
if %PAGE% GEQ %MAXPAGE% goto :EOF
if %PAGE% GEQ 10 goto :CONVERTPAGE10TO99
if %PAGE% GEQ 100 goto :CONVERTPAGE100
magick.exe "%FILENAME%.pdf"[%PAGE%] -density 200 "%FILENAME% 00%PAGE%.jpg"
set /a PAGE=%PAGE%+1
if %PAGE% GEQ %MAXPAGE% goto :EOF
if %PAGE% LSS 10 goto :CONVERTPAGE0TO9
:CONVERTPAGE10TO99
magick.exe "%FILENAME%.pdf"[%PAGE%] -density 200 "%FILENAME% 0%PAGE%.jpg"
set /a PAGE=%PAGE%+1
if %PAGE% GEQ %MAXPAGE% goto :EOF
if %PAGE% LSS 100 goto :CONVERTPAGE10TO99
:CONVERTPAGE100
magick.exe "%FILENAME%.pdf"[%PAGE%] -density 200 "%FILENAME% %PAGE%.jpg"
set /a PAGE=%PAGE%+1
if %PAGE% LSS %MAXPAGE% goto :CONVERTPAGE100
if %PAGE% GEQ %MAXPAGE% goto :EOF
goto :EOF
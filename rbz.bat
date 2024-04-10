echo off
"c:\Program Files\7-Zip\7z.exe" a -r -tzip CB_TimberFraming CB_TimberFraming CB_TimberFraming.rb
move /y CB_TimberFraming.zip CB_TimberFraming.rbz
if "%~1"=="" GOTO DONE
set ver=%1
move /y CB_TimberFraming.rbz CB_TimberFraming_%ver%.rbz
copy /y CB_TimberFraming_%ver%.rbz ..\Public
:DONE
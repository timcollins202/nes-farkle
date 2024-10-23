@del output\farkle.o
@del output\farkle.nes
@del output\farkle.map.txt
@del output\farkle.labels.txt
@del output\farkle.nes.ram.nl
@del output\farkle.nes.0.nl
@del output\farkle.nes.1.nl
@del output\farkle.nes.dbg
@echo.
@echo Compiling...
\cc65\bin\ca65 farkle.asm -g -o output\farkle.o
@IF ERRORLEVEL 1 GOTO failure
@echo.
@echo Linking...
\cc65\bin\ld65 -o output\farkle.nes -C farkle.cfg output\farkle.o -m output\farkle.map.txt -Ln output\farkle.labels.txt --dbgfile output\farkle.nes.dbg
@IF ERRORLEVEL 1 GOTO failure
@echo.
@echo Success!
@GOTO endbuild
:failure
@echo.
@echo Build error!
:endbuild
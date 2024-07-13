@del farkle.o
@del farkle.nes
@del farkle.map.txt
@del farkle.labels.txt
@del farkle.nes.ram.nl
@del farkle.nes.0.nl
@del farkle.nes.1.nl
@del farkle.nes.dbg
@echo.
@echo Compiling...
\cc65\bin\ca65 farkle.s -g -o farkle.o
@IF ERRORLEVEL 1 GOTO failure
@echo.
@echo Linking...
\cc65\bin\ld65 -o farkle.nes -C farkle.cfg farkle.o -m farkle.map.txt -Ln farkle.labels.txt --dbgfile farkle.nes.dbg
@IF ERRORLEVEL 1 GOTO failure
@echo.
@echo Success!
@GOTO endbuild
:failure
@echo.
@echo Build error!
:endbuild
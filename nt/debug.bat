@echo off 
set emacs_dir=c:\emacs

REM Here begins emacs.bat.in

REM Set OS specific values.
set ARCH_SAVE=%PROCESSOR_ARCHITECTURE%
set PROCESSOR_ARCHITECTURE=
if "%ARCH_SAVE%" == "%PROCESSOR_ARCHITECTURE%" goto win95
set PROCESSOR_ARCHITECTURE=%ARCH_SAVE%
set SHELL=cmd
goto next

:win95
set SHELL=command

:next

set EMACSLOADPATH=%emacs_dir%\lisp
set EMACSDATA=%emacs_dir%\etc
set EMACSPATH=%emacs_dir%\bin
set EMACSLOCKDIR=%emacs_dir%\lock
set INFOPATH=%emacs_dir%\info
set EMACSDOC=%emacs_dir%\etc
set TERM=CMD

REM The variable HOME is used to find the startup file, ~\_emacs.  Ideally,
REM this will not be set in this file but should already be set before
REM this file is invoked.  If HOME is not set, use some generic default.

set HOME_SAVE=%HOME%
set HOME_EXISTS=yes
set HOME_DEFAULT=C:\
set HOME=
if "%HOME%" == "%HOME_SAVE%" set HOME_EXISTS=no
if "%HOME_EXISTS%" == "yes" set HOME=%HOME_SAVE%
if "%HOME_EXISTS%" == "no" set HOME=%HOME_DEFAULT%
if "%HOME_EXISTS%" == "no" echo HOME is not set!  Using %HOME% as a default...

start c:\msdev\bin\msdev -nologo %emacs_dir%\bin\emacs.exe %1 %2 %3 %4 %5 %6 %7 %8 %9

$! PATCH$SETUP.COM - define the patch command for a user
$!
$! Add to LOGIN.COM (or SYS$MANAGER:SYLOGIN.COM for everyone):
$!     $ @PATCH$ROOT:[000000]PATCH$SETUP.COM
$!
$! Upper-case options (-B, -E, -R, -V, -Z, ...) need
$! SET PROCESS/PARSE_STYLE=EXTENDED, or double quotes, because traditional
$! DCL parsing changes their case; batch jobs use the traditional style.
$!
$ if f$trnlnm("PATCH$ROOT") .eqs. ""
$ then
$   write sys$error "PATCH$SETUP: PATCH$ROOT is not defined; run PATCH$STARTUP.COM first"
$   exit 44
$ endif
$ patch :== $PATCH$ROOT:[BIN]PATCH.EXE
$ exit 1

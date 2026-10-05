$! PATCH$STARTUP.COM - system startup for GNU patch on OpenVMS
$!
$! Installed by PCSI into SYS$STARTUP.  Defines the system logical name
$! PATCH$ROOT, pointing at the installed [PATCH] directory.  To run it at every
$! boot, add this line to SYS$MANAGER:SYSTARTUP_VMS.COM:
$!
$!     $ @SYS$STARTUP:PATCH$STARTUP.COM
$!
$! P1 = "INSTALL": also print the post-installation tasks (PCSI runs it so).
$! P1 = "REMOVE":  deassign PATCH$ROOT instead (PCSI runs it so at removal).
$!
$! Users then define the patch command with
$!     $ @PATCH$ROOT:[000000]PATCH$SETUP.COM
$!
$ set noon
$ mode = f$edit(p1, "UPCASE")
$ if mode .eqs. "REMOVE"
$ then
$   if f$trnlnm("PATCH$ROOT", "LNM$SYSTEM_TABLE") .nes. "" then -
        deassign/system/executive_mode PATCH$ROOT
$   exit 1
$ endif
$!
$! This procedure sits in <destination>[SYS$STARTUP]; the product is in
$! <destination>[PATCH].  Rooted logicals need the physical form:
$! DKA0:[SYS0.SYSCOMMON.SYS$STARTUP] -> DKA0:[SYS0.SYSCOMMON.PATCH.]
$ proc = f$environment("PROCEDURE")
$ dev = f$parse(proc,,,"DEVICE","NO_CONCEAL")
$ dir = f$edit(f$parse(proc,,,"DIRECTORY","NO_CONCEAL"), "UPCASE") - "]["
$ root = dir - "SYS$STARTUP]" + "PATCH.]"
$ if root .eqs. dir + "PATCH.]"
$ then
$   write sys$error "PATCH$STARTUP: expected to be in a [SYS$STARTUP] directory, not ''dir'"
$   exit 44
$ endif
$ root = root - ".000000"
$ define/system/executive_mode/translation_attributes=concealed PATCH$ROOT 'dev''root'
$ if f$search("PATCH$ROOT:[BIN]PATCH.EXE") .eqs. ""
$ then
$   write sys$error "PATCH$STARTUP: PATCH.EXE not found under ''dev'''root'"
$   exit 44
$ endif
$ if mode .nes. "INSTALL" then exit 1
$ say = "write sys$output"
$ say ""
$ say "    Post-installation tasks for GNU patch"
$ say ""
$ say "    At system startup: to define PATCH$ROOT at every boot, add this line to"
$ say "    SYS$MANAGER:SYSTARTUP_VMS.COM:"
$ say "    $ @SYS$STARTUP:PATCH$STARTUP.COM"
$ say "    For each user: to define the patch command, add this line to LOGIN.COM:"
$ say "    $ @PATCH$ROOT:[000000]PATCH$SETUP.COM"
$ say ""
$ say "    PRODUCT REMOVE PATCH removes the product and deassigns PATCH$ROOT."
$ say ""
$ exit 1

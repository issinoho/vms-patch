$! VMS_INSTALLCHECK.COM <tree-dir-name> - install the PATCH kit, verify, smoke-test
$! the installed image, then remove it.  Changes the system while it runs (PCSI
$! database, SYS$COMMON:[PATCH], system logical PATCH$ROOT); leaves it as it was.
$ set noon
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ base = "I64VMS"
$ if arch .eqs. "X86_64" then base = "X86VMS"
$ tree = f$environment("DEFAULT") - "]" + "." + p1 + "]"
$ kitdir = tree - "]" + ".KIT_''arch']"
$ write sys$output "=== INSTALL from ", kitdir
$ product install PATCH /producer=ISSINOHO /base_system='base' /source='kitdir' /options=noconfirm /log
$ write sys$output "=== install status ", $status
$ product show product PATCH /producer=ISSINOHO
$ write sys$output "=== VERIFY"
$ write sys$output "startup procedure: [", f$search("SYS$STARTUP:PATCH$STARTUP.COM"), "]"
$ show logical PATCH$ROOT
$ directory/nohead/notrail PATCH$ROOT:[000000...]*.*
$ @PATCH$ROOT:[000000]PATCH$SETUP.COM
$ show symbol patch
$ patch --version
$ write sys$output "=== SMOKE TEST on installed image"
$ smoke = tree - "]" + ".VMS]TEST_SMOKE.COM"
$ @'smoke' PATCH$ROOT:[BIN]PATCH.EXE
$ write sys$output "=== REMOVE"
$ product remove PATCH /producer=ISSINOHO /options=noconfirm /log
$ write sys$output "=== remove status ", $status
$ write sys$output "PATCH$ROOT after removal: [", f$trnlnm("PATCH$ROOT"), "]"
$ write sys$output "files after removal: [", f$search("SYS$COMMON:[PATCH...]*.*"), "]"
$ write sys$output "startup after removal: [", f$search("SYS$STARTUP:PATCH$STARTUP.COM"), "]"
$ product show product PATCH /producer=ISSINOHO
$ delete/symbol/global patch

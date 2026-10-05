$! TEST_SMOKE.COM - smoke test for the built GNU patch ([.BIN_<arch>]PATCH.EXE)
$!
$! Usage:  @[.VMS]TEST_SMOKE [image]
$! P1: the patch image to test (default [.BIN_<arch>]PATCH.EXE; the install
$!     check passes PATCH$ROOT:[BIN]PATCH.EXE).
$!
$ set noon
$ saved_default = f$environment("DEFAULT")
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ patch = "$" + f$parse("[.BIN_''arch']PATCH.EXE")
$ if p1 .nes. "" then patch = "$" + p1
$ write sys$output "SMOKE: testing ", patch - "$"
$ pass = 0
$ fail = 0
$ if f$search("SMOKE.DIR") .eqs. "" then create/directory [.SMOKE]
$ set default [.SMOKE]
$ set process/parse_style=extended
$!
$! 1. version
$ define/user sys$output out.txt
$ patch --version
$ search/nooutput out.txt "GNU patch 2"
$ sev = $severity
$ name = "version"
$ gosub check_success
$!
$! 2. a unified diff
$ create hello.c
#include <stdio.h>
int main (void)
{
  printf ("hello\n");
  return 0;
}
$ create u.diff
--- hello.c
+++ hello.c
@@ -1,6 +1,6 @@
 #include <stdio.h>
 int main (void)
 {
-  printf ("hello\n");
+  printf ("hello, OpenVMS\n");
   return 0;
 }
$ define/user sys$output out.txt
$ patch "-i" u.diff
$ sev = $severity
$ if sev .eq. 1
$ then
$   search/nooutput/exact hello.c "hello, OpenVMS"
$   sev = $severity
$ endif
$ name = "applies a unified diff"
$ gosub check_success
$!
$! 3. -R reverses it
$ define/user sys$output out.txt
$ patch "-R" "-i" u.diff
$ sev = $severity
$ if sev .eq. 1
$ then
$   define/user sys$output nla0:
$   search/nooutput/exact hello.c "hello, OpenVMS"
$   if $severity .eq. 1 then sev = 2
$ endif
$ name = "-R reverses it"
$ gosub check_success
$!
$! 4. a context diff, with a backup (-b)
$ create c.diff
*** hello.c
--- hello.c
***************
*** 2,6 ****
  int main (void)
  {
    printf ("hello\n");
!   return 0;
  }
--- 2,6 ----
  int main (void)
  {
    printf ("hello\n");
!   return 1;
  }
$ define/user sys$output out.txt
$ patch "-b" "-i" c.diff
$ sev = $severity
$ if sev .eq. 1
$ then
$   search/nooutput/exact hello.c "return 1;"
$   sev = $severity
$   if f$search("hello.c.orig") .eqs. "" then sev = 2
$ endif
$ name = "applies a context diff and keeps a backup (-b)"
$ gosub check_success
$!
$! 5. --dry-run changes nothing
$ copy/nolog hello.c before.c
$ define/user sys$output out.txt
$ patch "--dry-run" "-R" "-i" c.diff
$ sev = $severity
$ if sev .eq. 1
$ then
$   define/user sys$output nla0:
$   differences/output=nla0: hello.c before.c
$   sev = $severity
$ endif
$ name = "--dry-run leaves the file alone"
$ gosub check_success
$!
$! 6. a hunk that does not apply: an error status and a .rej file
$ create bad.diff
--- hello.c
+++ hello.c
@@ -1,3 +1,3 @@
-#include <nothere.h>
+#include <stdlib.h>
 int main (void)
 {
$ define/user sys$output out.txt
$ patch "-i" bad.diff
$ sev = $severity
$ if f$search("hello.c.rej") .eqs. "" then sev = 1
$ name = "a failing hunk gives an error status and hello.c.rej"
$ gosub check_failure
$!
$! 7. -p1 into a subdirectory
$ create/directory [.SRC]
$ copy/nolog before.c [.SRC]main.c
$ create p1.diff
--- a/src/main.c
+++ b/src/main.c
@@ -4,3 +4,3 @@
   printf ("hello\n");
-  return 1;
+  return 2;
 }
$ define/user sys$output out.txt
$ patch "-p1" "-i" p1.diff
$ sev = $severity
$ if sev .eq. 1
$ then
$   search/nooutput/exact [.SRC]main.c "return 2;"
$   sev = $severity
$ endif
$ name = "-p1 patches src/main.c"
$ gosub check_success
$!
$! 8. a missing patch file gives an error status
$ define/user sys$output out.txt
$ define/user sys$error nla0:
$ patch "-i" nonexistent.diff
$ sev = $severity
$ name = "missing patch file gives an error status"
$ gosub check_failure
$!
$ write sys$output "SMOKE: ''pass' passed, ''fail' failed"
$ delete/nolog [.SRC]*.*;*
$ set file/protection=o:rwed SRC.DIR
$ delete/nolog *.*;*
$ set default [-]
$ set file/protection=o:rwed SMOKE.DIR
$ delete/nolog SMOKE.DIR;
$ set default 'saved_default'
$ if fail .eq. 0 then exit 1
$ exit 44
$!
$check_success:
$ if sev .eq. 1
$ then
$   pass = pass + 1
$   write sys$output "PASS: ", name
$ else
$   fail = fail + 1
$   write sys$output "FAIL: ", name, " (severity ", sev, ")"
$   if f$search("out.txt") .nes. ""
$   then
$     write sys$output "   output was:"
$     type out.txt;0
$   endif
$ endif
$ return
$!
$check_failure:
$ if sev .eq. 2 .or. sev .eq. 4
$ then
$   pass = pass + 1
$   write sys$output "PASS: ", name
$ else
$   fail = fail + 1
$   write sys$output "FAIL: ", name, " (severity ", sev, ", expected an error)"
$   if f$search("out.txt") .nes. ""
$   then
$     write sys$output "   output was:"
$     type out.txt;0
$   endif
$ endif
$ return

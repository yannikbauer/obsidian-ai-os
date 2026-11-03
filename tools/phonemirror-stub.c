/* PhoneMirror stub: Contents/MacOS/PhoneMirror. Compiled by `phonemirror.sh rebuild`.
 *
 * launchd refuses a shell script as a bundle executable (spawn error 162), so the
 * bundle's executable is this binary, and the logic lives in Contents/Resources/launch.sh
 * (source: phonemirror-launcher.sh). exec keeps the PID through stub -> sh -> scrcpy,
 * so the window stays with bundle local.phonemirror. */
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    char self[PATH_MAX], script[PATH_MAX];
    uint32_t n = sizeof self;
    if (_NSGetExecutablePath(self, &n) != 0) return 1;
    char *slash = strrchr(self, '/');           /* .../Contents/MacOS/PhoneMirror */
    if (!slash) return 1;
    *slash = '\0';
    snprintf(script, sizeof script, "%s/../Resources/launch.sh", self);

    char *args[argc + 2];
    args[0] = "/bin/sh";
    args[1] = script;
    for (int i = 1; i < argc; i++) args[i + 1] = argv[i];
    args[argc + 1] = NULL;
    execv("/bin/sh", args);
    perror("execv /bin/sh");
    return 1;
}

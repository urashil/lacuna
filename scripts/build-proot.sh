#!/usr/bin/env bash
# Builds termux/proot for the Alpine build host and installs it to /usr/local/bin/proot.
# Alpine's proot 5.4.0 aborts in systemd-tmpfiles (AT_EMPTY_PATH handling) and breaks ldconfig; the termux fork doesn't.
# Needs: apk add build-base talloc-dev linux-headers bsd-compat-headers git
set -euo pipefail
src=${1:-$(cd "$(dirname "$0")/../.." && pwd)/work/src/proot-termux}
[[ -d $src ]] || git clone --depth 1 https://github.com/termux/proot.git "$src"
cd "$src/src"
cat > musl-compat.h <<'H'
#ifndef __ASSEMBLER__
#include <errno.h>
#ifndef TEMP_FAILURE_RETRY
#define TEMP_FAILURE_RETRY(e) ({ long _r; do _r = (long)(e); while (_r == -1L && errno == EINTR); _r; })
#endif
#ifndef MSG_COPY
#define MSG_COPY 040000
#endif
#endif
H
make clean >/dev/null 2>&1 || true
# the freestanding loader must not get Alpine's default stack protector / fortify
make -j"$(nproc)" CFLAGS="-O2 -fno-stack-protector -U_FORTIFY_SOURCE" \
    CPPFLAGS="-D_FILE_OFFSET_BITS=64 -D_LARGEFILE64_SOURCE -D_GNU_SOURCE -I. -include $PWD/musl-compat.h"
sudo install -m755 proot /usr/local/bin/proot

//
//  hs_init.c
//  SimpleXChat
//
//  Created by Evgeny on 22/11/2023.
//  Copyright © 2023 SimpleX Chat. All rights reserved.
//

#include <TargetConditionals.h>
#include "hs_init.h"

extern void hs_init_with_rtsopts(int * argc, char **argv[]);

void haskell_init(void) {
#if TARGET_OS_SIMULATOR
    // TrustChat: GHC 9.6.3's non-moving GC crashes in threadPaused (EXC_BAD_ACCESS in a ghc_worker) on the
    // x86_64 simulator when receiving messages; the copying GC is used there until the core is built with GHC >= 9.6.5.
    int argc = 4;
#else
    int argc = 5;
#endif
    char *argv[] = {
        "simplex",
        "+RTS", // requires `hs_init_with_rtsopts`
        "-A64m", // chunk size for new allocations
        "-H64m", // initial heap size
#if !TARGET_OS_SIMULATOR
        "-xn", // non-moving GC
#endif
        0
    };
    char **pargv = argv;
    hs_init_with_rtsopts(&argc, &pargv);
}

void haskell_init_nse(void) {
    int argc = 7;
    char *argv[] = {
        "simplex",
        "+RTS", // requires `hs_init_with_rtsopts`
        "-A256k", // chunk size for new allocations
        "-H512k", // initial heap size
        "-F0.5", // heap growth triggering GC
        "-Fd0.3", // memory return
        "-c", // compacting garbage collector
        0
    };
    char **pargv = argv;
    hs_init_with_rtsopts(&argc, &pargv);
}

void haskell_init_se(void) {
    int argc = 7;
    char *argv[] = {
        "simplex",
        "+RTS", // requires `hs_init_with_rtsopts`
        "-A1m", // chunk size for new allocations
        "-H1m", // initial heap size
        "-F0.5", // heap growth triggering GC
        "-Fd1", // memory return
        "-c", // compacting garbage collector
        0
    };
    char **pargv = argv;
    hs_init_with_rtsopts(&argc, &pargv);
}

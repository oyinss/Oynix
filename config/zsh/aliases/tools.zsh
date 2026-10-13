#!/bin/zsh

# Tool aliases

# lazygit
if [[ -x "$(command -v lazygit)" ]]; then
    alias lg='lazygit'
fi

# Codex Desktop
if [[ -x "$(command -v codex-desktop)" ]]; then
    alias codexm='codex-desktop'
fi

# T3 Code (nightly). A function rather than a plain alias because it branches.
#
# `t3c` launches the nightly, or refocuses the window when one is already running. Its job is
# the failure mode after a nightly upgrade: the old instance dies with SIGTRAP (Chromium's
# CHECK -- paru replaced its files while it was running) and leaves the single-instance files
# behind, so every later launch exits before it even writes a log, with no window and no error.
# Those files must only be dropped while nothing is running, otherwise a second instance would
# start against the same state database -- hence the pgrep split.
if [[ -x "$(command -v t3code-nightly)" ]]; then
    function t3c() {
        local -a pids=(${(f)"$(pgrep -x t3code 2>/dev/null)"})
        local cores

        if (( $#pids )); then
            print -r -- "t3code already running (pid ${(j:, :)pids}) -- focusing the window."
        else
            # Show any core dump first: the last crash is the usual reason a launch did nothing.
            cores=$(coredumpctl list /opt/t3code-nightly-bin/t3code 2>/dev/null | tail -n +2 | tail -3)
            if [[ -n $cores ]]; then
                print -r -- "recent t3code core dumps:"
                print -r -- "$cores"
            fi
            rm -f ~/.config/t3code-v2/Singleton{Lock,Socket,Cookie}
            print -r -- "starting t3code-nightly (stderr: ~/.t3/userdata/logs/desktop-launch.log)"
        fi

        # Detached (-&! = background + disown): the shell keeps its prompt, the app keeps its
        # own logs, and a shell exit does not take the window down with it.
        setsid t3code-nightly >~/.t3/userdata/logs/desktop-launch.log 2>&1 &!
    }
fi

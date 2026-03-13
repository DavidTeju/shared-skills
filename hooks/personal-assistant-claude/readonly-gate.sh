#!/usr/bin/env perl
# readonly-gate — Auto-approve read-only tool calls, defer writes to the user.
#
# HOW IT WORKS:
#   1. Named tools (Read, Grep, etc.) are checked against an allowlist.
#   2. Bash commands go through a two-phase classifier:
#      Phase 1 — Whole-command scan for known write patterns (rm, git push, redirects…).
#      Phase 2 — Split into pipeline segments; every segment must be provably read-only.
#   3. Anything not provably read-only is deferred to the normal permission system.
#
# SAFETY PRINCIPLE: When in doubt, defer. False negatives (asking the user) are
# safe; false positives (auto-approving a write) are not.
#
# Tests: .claude/hooks/test_readonly_gate.sh

use strict;
use warnings;

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# JSON helpers (lightweight — avoids module import overhead)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Extract a top-level string value from JSON by key name.
# Handles standard JSON escapes (\", \\, \n, \t).
sub json_str {
    my ($json, $key) = @_;
    if ($json =~ /"$key"\s*:\s*"((?:[^"\\]|\\.)*)"/) {
        my $val = $1;
        $val =~ s/\\"/"/g;
        $val =~ s/\\\\/\\/g;
        $val =~ s/\\n/\n/g;
        $val =~ s/\\t/\t/g;
        return $val;
    }
    return "";
}

# Extract a string from within tool_input: {"tool_input": {"key": "value"}}
sub json_input_str {
    my ($json, $key) = @_;
    if ($json =~ /"tool_input"\s*:\s*\{[^}]*?"$key"\s*:\s*"((?:[^"\\]|\\.)*)"/) {
        my $val = $1;
        $val =~ s/\\"/"/g;
        $val =~ s/\\\\/\\/g;
        $val =~ s/\\n/\n/g;
        $val =~ s/\\t/\t/g;
        return $val;
    }
    return "";
}


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Output — approve or defer
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sub approve {
    my ($reason) = @_;
    print qq({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "$reason"}});
    exit 0;
}

sub defer {
    # No output → defers to the normal permission system.
    # Respects bypass/acceptEdits mode.
    exit 0;
}


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Section 1: Tool name allowlists (anchored regex — exact match only)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

my @READONLY_TOOL_PATTERNS = (
    # Core Claude Code tools
    qr/^(Read|View|Glob|Grep|WebSearch|WebFetch|TaskOutput|TaskList|TaskGet
        |ListMcpResourcesTool|ReadMcpResourceTool|AskUserQuestion)$/x,

    # Notion MCP — read-only subset
    qr/^mcp__notion__notion-(fetch|search|get-comments|get-teams|get-users)$/,

    # Playwright — observation-only tools
    qr/^mcp__playwright__browser_(snapshot|take_screenshot|console_messages|network_requests)$/,

    # Serena — read/inspect tools
    qr/^mcp__plugin_serena_serena__(
        read_file|list_dir|find_file|search_for_pattern|get_symbols_overview
        |find_symbol|find_referencing_symbols|read_memory|list_memories
        |check_onboarding_performed|get_current_config|initial_instructions
    )$/x,

    # Context7 documentation lookup
    qr/^mcp__context7__(resolve-library-id|query-docs)$/,

    # Agent/task spawning — subagent tools are gated by this same hook
    qr/^(Task|TaskCreate|TaskUpdate)$/,
);


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Section 2: Bash command classification
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── Phase 1: Early-exit write patterns ──────────────────────────────────────────
# If any of these match ANYWHERE in the command string, it's a write — defer.

# Filesystem mutators: rm, mv, cp, mkdir, etc. preceded by a boundary.
my $WRITE_COMMANDS = qr/(?:^|\s|;|&&|\||\()(?:rm|mv|cp|mkdir|rmdir|chmod|chown|chgrp|ln|touch|truncate)\s/;

# Git commands that modify the repo.
my $GIT_WRITE = qr/git\s+(?:push|commit|reset|rebase|merge|checkout|stash|cherry-pick|tag|branch\s+-[dDmMcC])/;

# Package manager installs/upgrades.
my $PKG_WRITE = qr/(?:npm|yarn|pnpm|pip|brew)\s+(?:install|uninstall|remove|add|upgrade|update|link)/;

# Docker commands that modify containers/images.
my $DOCKER_WRITE = qr/docker\s+(?:rm|rmi|stop|kill|build|push|run|exec|compose)/;

# curl with explicit write method or data.
my $CURL_WRITE = qr/curl\s+.+(?:-X\s+(?:POST|PUT|PATCH|DELETE)|--data|-d\s)/;

# sed in-place editing.
my $SED_WRITE = qr/sed\s+(?:-[a-zA-Z]*i|-i)/;

my @EARLY_WRITE_PATTERNS = ($WRITE_COMMANDS, $GIT_WRITE, $PKG_WRITE, $DOCKER_WRITE, $CURL_WRITE, $SED_WRITE);

# Output redirects that write to files (but NOT stderr merges like 2>&1).
my $REDIRECT = qr/(?:>>|>\||>[^&>])/;


# ── Phase 2: Per-segment classification ─────────────────────────────────────────

# Simple, single-word commands known to be read-only.
# Some have flag-level exceptions checked separately (find -exec, awk system(), etc.)
my %READONLY_CMDS = map { $_ => 1 } qw(
    cd pwd ls find cat head tail wc file stat du df echo printf date
    whoami hostname uname env printenv which type command realpath dirname
    basename sort uniq tr cut awk sed grep rg jq yq diff comm tree less
    more bat fd fzf ps top htop uptime free id groups locale man help
    test true false nproc getconf read shasum md5 md5sum sha256sum column
    rev tac nl fold paste join expand unexpand sw_vers xcode-select cal
    dig nslookup host ping traceroute whois ifconfig netstat lsof mdfind
    sysctl diskutil system_profiler scutil pbpaste
);

# ── Dangerous flags on "readonly" commands ──
# These flags make otherwise-safe commands perform writes.

my $FIND_WRITE_FLAGS  = qr/-(?:exec|execdir|delete|ok|okdir|fprint|fprint0|fprintf|fls)\b/;
my $AWK_WRITE_FLAGS   = qr/(?:\bsystem\s*\(|-f\s)/;
my $SED_SEGMENT_WRITE = qr/(?:-f\s|\bw\s+\/|['"][0-9]*e\s|\/e['"]|\/e\s|\/e$)/;
my $SORT_WRITE_FLAG   = qr/\s-o(?:\s|$)/;
my $LESS_WRITE_FLAG   = qr/(?:\s-o(?:\s|$)|\+!)/;

# ── Multi-word read patterns ──
# Compound commands (git log, gh pr list, etc.) that are read-only.

my $GIT_READ = qr/^\s*git\s+(?:log|status|diff|branch|show|remote|rev-parse|describe
                               |shortlog|blame|ls-files|ls-tree|config\s+--get)/x;

my $GOG_READ = qr/^\s*gog\s+(?:calendar|contacts|gmail|drive|sheets|docs)\s+
                              (?:events|list|get|search|read|view|messages\s+search|cat|export|metadata)/x;

my $BEEPER_READ = qr/^\s*(?:beeper-desktop-cli|beeper|scripts\/beeper)\s+
                               (?:chats|messages|accounts|search|info)\s*(?:list|search|retrieve|--|$)/x;

my $GH_READ = qr/^\s*gh\s+(?:
    pr\s+(?:list|view|status|diff|checks)
    |issue\s+(?:list|view|status)
    |run\s+(?:list|view)
    |release\s+(?:list|view)
    |repo\s+view
    |auth\s+status
    |search\s
    |workflow\s+(?:list|view)
)/x;

my $DOCKER_READ = qr/^\s*docker\s+(?:ps|images|inspect|logs|version|info
                                     |network\s+ls|volume\s+ls|stats|top|port|history|diff)/x;

my $PKG_READ = qr/^\s*(?:npm|yarn|pnpm)\s+(?:list|info|view|audit|outdated|pack|explain|ls|why|config\s+get)
                  |^\s*brew\s+(?:list|info|search|doctor|deps|leaves|outdated|config|tap|--prefix)
                  |^\s*pip\s+(?:list|show|freeze|check|config)/x;

my @MULTI_WORD_READ = ($GIT_READ, $GOG_READ, $BEEPER_READ, $GH_READ, $DOCKER_READ, $PKG_READ);

# ── Git-specific write checks ──
# These catch write operations hiding inside "git read" commands.
my $GIT_OUTPUT_FLAG  = qr/--output/;
my $GIT_REMOTE_WRITE = qr/remote\s+(?:remove|set-url|add|rename|prune)/;
my $GIT_BRANCH_WRITE = qr/branch\s+(?:--move|--set-upstream|-[muM](?:\s|$))/;

# ── gh api special handling ──
my $GH_API_READ         = qr/^\s*gh\s+api\s/;
my $GH_API_WRITE_FLAGS  = qr/-[Xx](?:\s|[A-Z]|$)|-[fF](?:\s|[a-z=]|$)|--input(?:\s|$)/;
my $GH_API_METHOD_WRITE = qr/--method[= ]*(?:POST|PUT|PATCH|DELETE|post|put|patch|delete)/;

# ── curl classification ──
my $CURL_READ        = qr/^\s*curl\s/;
my $CURL_WRITE_FLAGS = qr/-[XdToF]|--data|--output|--upload-file|--form/;

# ── Version flag (any-command --version / -v / version) ──
my $VERSION_CMD = qr/^\s*[a-zA-Z][a-zA-Z0-9_.-]*\s+(?:--version|-[vV]|version)\s*$/;

# ── Env/command prefix stripping ──
my $ENV_CMD_PREFIX = qr/^(?:command|env)\s+[^-]/;
my $STRIP_PREFIX   = qr/^(?:command|env)\s+/;
my $STRIP_ENV_VARS = qr/^(?:[A-Za-z_][A-Za-z_0-9]*=[^ ]*\s+)*/;

# ── Shell control flow ──
my $CONTROL_KW   = qr/^(?:while|do|if|then|else|elif|case)\s+/;
my $SKIP_SEGMENT = qr/^(?:\#|for\s|(?:done|fi|esac)\s*$)/;

# ── Process/command substitution ──
my $PROC_SUB       = qr/<\(|>\(/;
my $CMD_SUB        = qr/\$\(/;
my $NESTED_CMD_SUB = qr/\$\([^)]*\$\(/;
my $CMD_SUB_RE     = qr/\$\([^)]+\)?/;


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Bash classification logic
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check whether a single command (no pipes/chains) is read-only.
sub is_cmd_readonly {
    my ($cmd) = @_;
    $cmd =~ s/^\s+|\s+$//g;
    return 1 if $cmd eq "";

    # Strip command/env prefix wrapper.
    if ($cmd =~ $ENV_CMD_PREFIX) {
        $cmd =~ s/$STRIP_PREFIX//;
        $cmd =~ s/$STRIP_ENV_VARS//;
    }
    $cmd =~ s/^\s+|\s+$//g;
    return 1 if $cmd eq "";

    my ($word) = split(/\s+/, $cmd, 2);

    # ── Single-word readonly commands ──
    if ($READONLY_CMDS{$word}) {

        # Flag-level exceptions: some readonly commands have dangerous flags.
        return 0 if $word eq "find" && $cmd =~ $FIND_WRITE_FLAGS;
        return 0 if $word eq "awk"  && $cmd =~ $AWK_WRITE_FLAGS;
        return 0 if $word eq "sed"  && $cmd =~ $SED_SEGMENT_WRITE;
        return 0 if $word eq "sort" && $cmd =~ $SORT_WRITE_FLAG;
        return 0 if $word eq "less" && $cmd =~ $LESS_WRITE_FLAG;

        # env: bare "env" or "env VAR=val" is readonly, but wrapping a
        # command (env FOO=1 rm -rf /) needs recursive checking.
        if ($word eq "env") {
            (my $inner = $cmd) =~ s/^env(?:\s+(?:-[a-zA-Z]+|--[a-zA-Z-]+))*\s*//;
            $inner =~ s/$STRIP_ENV_VARS//;
            return 0 if $inner ne "" && !is_cmd_readonly($inner);
        }

        # command: "command -v git" is readonly (lookup). Otherwise it wraps
        # another command that needs recursive checking.
        if ($word eq "command") {
            unless ($cmd =~ /^command\s+-[vV]/) {
                (my $inner = $cmd) =~ s/^command(?:\s+(?:-[a-zA-Z]+))*\s*//;
                return 0 if $inner ne "" && !is_cmd_readonly($inner);
            }
        }

        return 1;
    }

    # ── Version flag (any-command --version) ──
    return 1 if $cmd =~ $VERSION_CMD;

    # ── Multi-word read patterns (git log, gh pr list, gog calendar events…) ──
    for my $pat (@MULTI_WORD_READ) {
        if ($cmd =~ $pat) {
            # Git commands need extra write-flag checks.
            if ($cmd =~ /^\s*git\s/) {
                return 0 if $cmd =~ $GIT_OUTPUT_FLAG;
                return 0 if $cmd =~ $GIT_REMOTE_WRITE;
                return 0 if $cmd =~ $GIT_BRANCH_WRITE;
            }
            return 1;
        }
    }

    # ── gh api: GET by default, but write flags change the method ──
    if ($cmd =~ $GH_API_READ) {
        unless ($cmd =~ $GH_API_WRITE_FLAGS) {
            return 0 if $cmd =~ $GH_API_METHOD_WRITE;
            return 1;
        }
    }

    # ── curl: plain curl (no write flags) is a GET ──
    if ($cmd =~ $CURL_READ) {
        return 1 unless $cmd =~ $CURL_WRITE_FLAGS;
    }

    # Unknown command — not provably read-only.
    return 0;
}


# Remove safe stderr redirects (2>/dev/null, 2>&1) so they don't false-positive
# the write-redirect check.
sub strip_safe_stderr {
    my ($cmd) = @_;
    $cmd =~ s/[0-9]+>(?:>?)(?:\/dev\/null|&[0-9]+)//g;
    return $cmd;
}


# Classify a full bash command string as read-only (1) or not (0).
#
# Strategy:
#   Phase 1 — Scan the whole command for known write patterns. Bail early.
#   Phase 2 — Split on |, &&, ;, || into segments. Every segment must pass.
sub classify_bash {
    my ($command) = @_;
    $command =~ s/^\s+|\s+$//g;
    return 1 if $command eq "";

    # ── Phase 1: Whole-command write pattern scan ──

    # Backticks can hide arbitrary commands.
    return 0 if $command =~ /`/;

    # Check each early-exit write pattern.
    for my $pat (@EARLY_WRITE_PATTERNS) {
        return 0 if $command =~ $pat;
    }

    # Check for file-writing redirects (after stripping safe stderr merges).
    my $for_redirect = strip_safe_stderr($command);
    return 0 if $for_redirect =~ $REDIRECT;

    # ── Phase 2: Per-segment analysis ──
    # Split on shell operators (naive — doesn't respect quotes, errs on safe side).
    my @segments = split(/\|\||&&|;|\|/, $command);

    for my $segment (@segments) {
        # Strip whitespace, subshell parens.
        my $s = $segment;
        $s =~ s/^\s+|\s+$//g;
        $s =~ s/^\(+\s*//;
        $s =~ s/\s*\)+$//;
        $s =~ s/^\s+|\s+$//g;

        # Skip empty segments, comments, for-loop bindings, bare control tokens.
        next if $s eq "" || $s =~ $SKIP_SEGMENT;

        # Strip up to 2 leading control keywords (while, do, if, then…).
        $s =~ s/$CONTROL_KW//;
        $s =~ s/$CONTROL_KW//;
        next if $s eq "";

        # Strip command/env prefix wrapper.
        if ($s =~ $ENV_CMD_PREFIX) {
            $s =~ s/$STRIP_PREFIX//;
            $s =~ s/$STRIP_ENV_VARS//;
        }
        next if $s eq "";

        # Check whether this segment is read-only.
        my $is_ro = is_cmd_readonly($s);

        # Process substitution <() / >() can hide arbitrary commands.
        $is_ro = 0 if $is_ro && $s =~ $PROC_SUB;

        # Smart $() inspection: check the inner commands rather than blanket-deferring.
        if ($is_ro && $s =~ $CMD_SUB) {
            if ($s =~ $NESTED_CMD_SUB) {
                # Nested $($()) is too complex to parse safely.
                $is_ro = 0;
            } else {
                # Extract each $(…) block and verify its inner commands.
                while ($s =~ /($CMD_SUB_RE)/g) {
                    my $match = $1;
                    $match =~ s/^\$\(//;    # strip leading $(
                    $match =~ s/\)$//;      # strip trailing )
                    next if $match eq "";

                    # Inner commands can have pipes — check each sub-segment.
                    for my $inner_seg (split(/\|/, $match)) {
                        $inner_seg =~ s/^\s+|\s+$//g;
                        next if $inner_seg eq "";
                        unless (is_cmd_readonly($inner_seg)) {
                            $is_ro = 0;
                            last;
                        }
                    }
                    last unless $is_ro;
                }
            }
        }

        return 0 unless $is_ro;
    }

    return 1;
}


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main entry point
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

my $input = do { local $/; <STDIN> };
my $tool_name = json_str($input, "tool_name");

# ── Check read-only tool allowlists ──
for my $pattern (@READONLY_TOOL_PATTERNS) {
    approve("Read-only: auto-approved") if $tool_name =~ $pattern;
}

# ── browser_tabs: needs input-level inspection ──
if ($tool_name eq "mcp__playwright__browser_tabs") {
    my $action = json_input_str($input, "action");
    if ($action eq "list") {
        approve("Read-only: browser_tabs list");
    } else {
        defer();
    }
}

# ── Bash command classification ──
if ($tool_name eq "Bash") {
    my $command = json_input_str($input, "command");
    if (classify_bash($command)) {
        approve("Read-only bash: auto-approved");
    }
    defer();
}

# ── Everything else → defer to permission system ──
defer();

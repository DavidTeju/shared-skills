#!/usr/bin/env perl
# eslint-config-protector — Block agents from editing ESLint config files.
#
# If a rule is genuinely blocking progress, the agent must report back
# to the human and explain why — not silently weaken the guardrails.

use strict;
use warnings;

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

sub block {
    my ($reason) = @_;
    $reason =~ s/"/\\"/g;
    print qq({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "$reason"}});
    exit 0;
}

sub pass { exit 0; }

# ── Main ──

my $input = do { local $/; <STDIN> };
my $tool_name = json_str($input, "tool_name");

# Only inspect tools that write files
unless ($tool_name eq "Write" || $tool_name eq "Edit" || $tool_name eq "NotebookEdit") {
    pass();
}

# Check file_path for ESLint config patterns
my $file_path = json_input_str($input, "file_path");
pass() if $file_path eq "";

# Extract just the filename
(my $filename = $file_path) =~ s|^.*/||;

# Match all ESLint config file patterns:
#   eslint.config.{js,mjs,cjs,ts,mts,cts}
#   .eslintrc.{js,mjs,cjs,json,yml,yaml}
#   .eslintrc
if ($filename =~ /^eslint\.config\.[mc]?[jt]s$/ ||
    $filename =~ /^\.eslintrc(?:\.[mc]?js|\.json|\.ya?ml)?$/) {

    block(
        "\\n" .
        "============================================================\\n" .
        "  BLOCKED: ESLint config modification detected\\n" .
        "============================================================\\n" .
        "\\n" .
        "  You may NOT edit ESLint configuration files.\\n" .
        "  The rules exist for a reason. Work within them.\\n" .
        "\\n" .
        "  If a lint rule genuinely makes your task impossible:\\n" .
        "    1. STOP what you are doing\\n" .
        "    2. Report to the user which rule is blocking you\\n" .
        "    3. Explain WHY it conflicts with the task\\n" .
        "    4. Let the HUMAN decide whether to change the config\\n" .
        "\\n" .
        "  You are NOT authorized to weaken guardrails yourself.\\n" .
        "\\n" .
        "============================================================\\n"
    );
}

pass();

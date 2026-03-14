#!/usr/bin/env perl
# eslint-disable-blocker — Block any Write/Edit that contains "eslint-disable".
#
# Agents must fix ESLint issues properly, not suppress them.

use strict;
use warnings;

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# JSON helpers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Output
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sub block {
    my ($reason) = @_;
    # Escape any double quotes in reason for valid JSON
    $reason =~ s/"/\\"/g;
    print qq({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "$reason"}});
    exit 0;
}

sub pass {
    # No output → continue normally
    exit 0;
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

my $input = do { local $/; <STDIN> };
my $tool_name = json_str($input, "tool_name");

# Skip tools that can't write content
my @SKIP_TOOLS = qw(Read Glob Grep WebSearch WebFetch AskUserQuestion
    TaskGet TaskList TaskOutput ListMcpResourcesTool ReadMcpResourceTool);
my %skip = map { $_ => 1 } @SKIP_TOOLS;

# Also skip known read-only MCP tools (serena read/find/list, context7, notion fetch/search)
if ($skip{$tool_name} ||
    $tool_name =~ /^mcp__plugin_serena_serena__(?:read_file|list_dir|find_file|search_for_pattern|
        get_symbols_overview|find_symbol|find_referencing_symbols|
        read_memory|list_memories|check_onboarding_performed|
        get_current_config|initial_instructions)$/x ||
    $tool_name =~ /^mcp__context7__/ ||
    $tool_name =~ /^mcp__notion__notion-(?:fetch|search|get-)/) {
    pass();
}

# Check the ENTIRE input payload for eslint-disable patterns.
# This catches Write, Edit, Bash (echo/sed/cat), Serena write tools,
# and any other tool that might sneak eslint-disable into code.
# Patterns caught: eslint-disable, eslint-disable-next-line, eslint-disable-line
if ($input =~ /eslint-disable(?:(?:-next)?-line)?(?:\s|[^-\w]|$)/) {
    block(
        "\\n" .
        "============================================================\\n" .
        "  BLOCKED: eslint-disable detected\\n" .
        "============================================================\\n" .
        "\\n" .
        "  Hacking ESLint rules will result in IMMEDIATE TERMINATION.\\n" .
        "\\n" .
        "  You MUST fix ESLint issues properly:\\n" .
        "    - Fix the actual code that violates the rule\\n" .
        "    - If the rule itself is wrong, update the ESLint config\\n" .
        "    - NEVER suppress warnings with eslint-disable comments\\n" .
        "\\n" .
        "  STOP. Think HARD about the actual proper solution.\\n" .
        "  The lint rule exists for a reason. Respect it.\\n" .
        "\\n" .
        "============================================================\\n"
    );
}

pass();

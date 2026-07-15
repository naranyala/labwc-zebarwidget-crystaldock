# Lesson: `ExecTerm()` Is Not A Valid zigshell-cairo-pango Function

## The Problem

15 widget files use `ExecTerm()` in their click actions, but zigshell-cairo-pango does not provide this function:

```ini
# volume-text.widget:71
label { value = "Click to open alsamixer" }
action[LeftClick] = ExecTerm("alsamixer")
```

When the user clicks, **nothing happens**. No error, no terminal, no command.

## Root Cause

Standard zigshell-cairo-pango provides `Exec()` for running commands. `ExecTerm()` is not defined in the zigshell-cairo-pango expression library. All 15 usages are silent no-ops.

The variables in question may appear to be proper function calls but are not recognized by zigshell-cairo-pango's parser. They silently fail because the expression evaluator returns `nil` for unknown function names.

## Affected Files

| File | Line | Bad Call |
|------|------|----------|
| `volume-text.widget` | 71 | `ExecTerm("alsamixer")` |
| `temperature.widget` | 8 | `ExecTerm("...")` |
| `sysmon.widget` | 62 | `ExecTerm("htop")` |
| `power-profile.widget` | 81 | `ExecTerm("...")` |
| `custom-script.widget` | 56 | `ExecTerm("...")` |
| `disk.widget` | 67 | `ExecTerm("ncdu")` |
| `cpu-text.widget` | 8 | `ExecTerm("...")` |
| `memory-text.widget` | 8 | `ExecTerm("...")` |
| `memory-monitor.widget` | 72 | `ExecTerm("htop")` |
| `cpu-monitor.widget` | 79 | `ExecTerm("htop")` |
| `clipboard.widget` | 59 | `ExecTerm("...")` |
| `battery-text.widget` | 41 | `ExecTerm("upower -i ...")` |
| `media-player.widget` | 91 | `ExecTerm("...")` |
| `network-text.widget` | 64 | `ExecTerm("...")` |
| `network-bandwidth.widget` | 40 | `ExecTerm("...")` |

## The Fix

Replace `ExecTerm()` with `Exec()` and wrap the command in a terminal invocation:

```ini
# Before:
action[LeftClick] = ExecTerm("alsamixer")

# After:
action[LeftClick] = Exec("foot -e alsamixer")
#                    or
action[LeftClick] = Exec("kitty -e alsamixer")
#                    or
action[LeftClick] = Exec("alacritty -e alsamixer")
```

Or, if you want a configurable terminal, use a variable:

```ini
# At the top of the config:
Set Term = "foot"

# In the widget:
action[LeftClick] = Exec(Term + " -e htop")
```

## Pattern To Remember

zigshell-cairo-pango has a limited set of built-in functions (`Exec`, `If`, `Match`, `Extract`, `Grab`, `Val`, `Str`, `Time`, `Format`, `Pad`, etc.). If a function name is not in that list, it returns `nil` and is silently ignored. Always verify function names against the zigshell-cairo-pango expression library.

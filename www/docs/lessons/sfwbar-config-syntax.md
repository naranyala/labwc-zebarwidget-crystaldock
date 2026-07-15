# Lesson: zigshell-cairo-pango Config Syntax Is Not Bash

## The Problem

zigshell-cairo-pango config files (`.widget`, `.config`, `.source`) look similar to shell scripts but use a **completely different syntax**. Mixing bash constructs into zigshell-cairo-pango config causes silent failures or parse errors.

## What zigshell-cairo-pango Supports

### Control Flow

```ini
# zigshell-cairo-pango uses If() with capitalized I and parenthesized args
If(XBatLvl > 80, "high", "low")

# Not bash-style:
# if [ $bat -gt 80 ]; then echo "high"; fi
```

### Functions

```ini
# zigshell-cairo-pango Function declaration
Function MyFunc() {
  Return "hello"
}

# Not bash-style:
# my_func() { echo "hello"; }
```

### Variable Scoping

```ini
# zigshell-cairo-pango uses "local" keyword (not "local" with type)
Private {
  Var my_var = "value"
}

# Not bash-style:
# local my_var="value"
```

### Shell Commands

```ini
# Use Exec() to run shell commands
action = Exec("pactl set-volume @DEFAULT_SINK@ 0.05+")

# Not bash-style:
# pactl set-volume @DEFAULT_SINK@ 0.05+
```

## What zigshell-cairo-pango Does NOT Support

| Bash Construct | zigshell-cairo-pango Equivalent |
|---|---|
| `if [ condition ]; then ... fi` | `If(condition, true_val, false_val)` |
| `elif` | Nested `If()` |
| `command -v foo` | `Ident(foo)` or check at shell level |
| `echo "text" > file` | `Exec("echo text > file")` |
| `mkdir -p dir` | `Exec("mkdir -p dir")` |
| `$((expr))` | `Val(expr)` or inline math |
| `function name() { }` | `Function name() { }` |
| `local var=value` | `Var var = value` inside `Private {}` |

## Example: Incorrect vs Correct

### WRONG (bash in zigshell-cairo-pango config)

```ini
ExecuteApp() {
  local app_name="$1"
  if command -v kitty >/dev/null 2>&1; then
    kitty -e "bash -c '$app_name'"
  elif command -v foot >/dev/null 2>&1; then
    foot -e "bash -c '$app_name'"
  fi
}
```

### CORRECT (zigshell-cairo-pango syntax)

```ini
Function ExecuteApp() {
  Exec("fuzzel --command " + $1)
}
```

## Rule of Thumb

If a line uses bash features (`$()`, `[]`, `if/elif/else`, `echo`, pipes `|`), it belongs in a **shell script** called via `Exec()`, not inline in zigshell-cairo-pango config.

Inline zigshell-cairo-pango config should only use: `If()`, `Exec()`, `Val()`, `Str()`, `Match()`, `RegEx()`, and zigshell-cairo-pango's built-in functions.

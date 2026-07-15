# IPC Command Injection and Unescaped Strings

## The Problem
When reviewing the codebase for string safety and sanitization, I found a vulnerability in how `ocws-emit.sh` pushes string variables (like media player metadata) into the `zigshell-cairo-pango` IPC socket.

The `ocws-emit.sh` script wraps string values in double quotes like this:
```bash
IPC_CMD="SetVal ${ENGINE_VAR} = \"${VAL}\""
```

If a string naturally contained double quotes (for example, a song title like `Bob "The Builder" Theme`), the resulting IPC command would be:
```bash
SetVal XMediaTitle = "Bob "The Builder" Theme"
```
This breaks the underlying parser because the quotes are mismatched, causing `zigshell-cairo-pango` to silently drop the event update, or worse, leaving it open to potential injection vulnerabilities if it evaluates the unquoted text as further commands.

## The Solution
When wrapping strings in double quotes for an IPC parser or shell command, you must always aggressively sanitize or escape the input string itself.

I modified `ocws-emit.sh` to escape inner double quotes using bash parameter expansion (`//`) before wrapping the string:
```bash
VAL="${VAL//\"/\\\"}"
IPC_CMD="SetVal ${ENGINE_VAR} = \"${VAL}\""
```

Now, the same song title results in:
```bash
SetVal XMediaTitle = "Bob \"The Builder\" Theme"
```
This is correctly parsed by the `zigshell-cairo-pango` engine, ensuring your media widgets (and other string-based widgets) never freeze or crash when encountering special characters.

# Lesson: Private Blocks and Global Scope in zigshell-cairo-pango

## The Problem

Variables and functions defined at the top level of a `.widget` file are **global** — they can conflict with identically named variables in other widget files.

## Three Scope Levels

### 1. Global (default)

```ini
# In volume-text.widget
scanner {
  step = 2000
  exec("...") { XVolLevel = ... }
}

export button "volume-text" { ... }
```

`XVolLevel` is global. Any other widget that defines `XVolLevel` will overwrite it.

### 2. Private Block

```ini
# In workspaces.widget
Private {
  Var my_internal_var = "value"

  Function MyHelper() { ... }

  export button "workspaces" { ... }

  PopUp("WsPopup") { ... }
}
```

Everything inside `Private {}` is scoped to this widget file. Other widgets can't see `my_internal_var` or `MyHelper()`.

### 3. Function Scope

```ini
Function MyFunc() {
  Var local_var = "only inside this function"
  # local_var is destroyed when the function returns
}
```

## When to Use `Private {}`

| Use Case | Use Private? |
|---|---|
| Widget has internal variables that other widgets don't need | YES |
| Widget defines helper functions | YES |
| Widget has a scanner that other widgets also read from | NO (keep global) |
| Widget exports a button/label to the bar | The export itself is global, but internals can be Private |
| PopUp definition that's only used by this widget | YES |

## Common Pattern

```ini
Private {
  # Scanner — sets global variables that THIS widget reads
  scanner {
    step = 2000
    exec("...") { XMyVar = ... }
  }

  # Internal helper — not visible outside
  Function FormatValue() {
    Return Str(XMyVar, 0) + "%"
  }

  # Exported button — visible to the bar
  export button "my-widget" {
    style = "text_widget"
    label { value = FormatValue() }
  }

  # Popup — only triggered by this widget
  PopUp("MyPopup") {
    style = "detail_popup"
    grid {
      style = "detail_grid"
      label { value = "Detail: " + FormatValue() }
    }
  }
}
```

## Conflict Example

```ini
# Widget A defines:
scanner { exec("...") { XBrightness = ... } }

# Widget B also defines:
scanner { exec("...") { XBrightness = ... } }
```

Both scanners write to the same global variable. The last one to run wins. Fix: put one scanner in a `Private {}` block and rename the variable, or consolidate both scanners into a single source file.

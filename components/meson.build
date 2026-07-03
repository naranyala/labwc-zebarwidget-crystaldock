project('labwc-widgets', 'c',
  version: '1.0.0',
  license: 'MIT',
  default_options: [
    'c_std=c11',
    'warning_level=2',
    'optimization=2',
    'strip=true'
  ])

# Dependencies
wayland_client = dependency('wayland-client', required: true)
wayland_protos = dependency('wayland-protocols', required: true)

# wlr-layer-shell (via pkg-config or fallback)
wlr_layer_shell = dependency('wlr-layer-shell', required: false)
if not wlr_layer_shell.found()
  # Try to find via wayland-scanner
  wlr_layer_shell = declare_dependency(
    compile_args: ['-DWLR_LAYER_SHELL_PROTOCOL'])
endif

cairo = dependency('cairo', required: true)
pango = dependency('pangocairo', required: true)
pango_ft = dependency('pangoft2', required: true)
fontconfig = dependency('fontconfig', required: true)
xkbcommon = dependency('xkbcommon', required: true)
libinput = dependency('libinput', required: false)
json_glib = dependency('json-glib-1.0', required: false)

# If json-glib not found, use simple JSON parser
if not json_glib.found()
  json_glib = declare_dependency(compile_args: ['-DUSE_SIMPLE_JSON'])
endif

# Wayland protocol generation
wayland_scanner = find_program('wayland-scanner', required: true)

# Generate wlr-layer-shell protocol header
wlr_layer_shell_xml = wayland_protos.get_variable_pkgdir() / 'wlr-layer-shell-unstable-v1.xml'
wlr_layer_shell_gen = custom_target('wlr-layer-shell-protocol',
  input: wlr_layer_shell_xml,
  output: ['wlr-layer-shell-unstable-v1-client-protocol.h', 'wlr-layer-shell-unstable-v1-protocol.c'],
  command: [wayland_scanner, 'client-header', '@INPUT@', '@OUTPUT0@'],
  console: true)

# Shared library: libwidget
libwidget_sources = [
  'libwidget/widget.c',
  'libwidget/providers/system.c',
  'libwidget/wayland/layer-shell.c',
  'libwidget/render/render.c',
  'libwidget/render/font.c',
]

libwidget = library('widget',
  libwidget_sources,
  wlr_layer_shell_gen,
  dependencies: [
    wayland_client,
    wlr_layer_shell,
    cairo,
    pango,
    pango_ft,
    fontconfig,
    xkbcommon,
    json_glib,
  ],
  include_directories: include_directories('libwidget/include'),
  install: true,
  soversion: 1)

# Export include directory
widget_inc = include_directories('libwidget/include')

# Widget executables
widget_names = ['clock', 'cpu', 'memory', 'network', 'battery', 'volume']
foreach name : widget_names
  executable('widget-' + name,
    'widgets/@0@/@0@.c'.format(name),
    link_with: libwidget,
    include_directories: widget_inc,
    install: true)
endforeach

# Statusbar executables
statusbar_names = ['main', 'compact', 'panel', 'detailed', 'minimalist']
foreach name : statusbar_names
  executable('statusbar-' + name,
    'statusbars/' + name + '/' + name + '.c',
    link_with: libwidget,
    include_directories: widget_inc,
    install: true)
endforeach

# Unified statusbar framework source files
framework_sources = [
  'statusbars/framework.c',
]

# Create unified statusbar library
statusbar_framework = library('statusbar-framework',
  framework_sources,
  dependencies: [
    wayland_client,
    wlr_layer_shell,
    cairo,
    pango,
    pango_ft,
    fontconfig,
    xkbcommon,
    json_glib,
    libwidget,
  ],
  include_directories: widget_inc + include_directories('.'),
  install: true,
  soversion: 1)

# Example usage of the unified framework (commented out to avoid duplicate main)
# executable('statusbar-core-test',
#   'statusbars/core.c',
#   link_with: libwidget statusbar_framework,
#   include_directories: widget_inc,
#   install: false)

# Install registry
install_data('registry.json', install_dir: get_option('datadir') / 'labwc-widgets')

# Summary
message('=== labwc-widgets build configuration ===')
message('Widgets: ' + ', '.join(widget_names))
message('Statusbars: ' + ', '.join(statusbar_names))
message('Dependencies:')
message('  wayland-client: ' + wayland_client.found().to_string())
message('  wlr-layer-shell: ' + wlr_layer_shell.found().to_string())
message('  cairo: ' + cairo.found().to_string())
message('  pangocairo: ' + pango.found().to_string())
message('  xkbcommon: ' + xkbcommon.found().to_string())

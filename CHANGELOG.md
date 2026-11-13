## [Unreleased]

### Fixed
- Subtemplates now escape interpolated values. They were compiled with plain `ERB` and the whole output was marked `html_safe`, so user input rendered through `<%= %>` was inserted as raw HTML. Values already marked `html_safe` are still rendered as-is.

### Changed
- **Breaking:** block helpers that return their output (`fields_for`, `simple_fields_for`, `form_with`, `content_tag`, etc.) must be called with `<%=`, as in any Rails template. With plain `ERB`, `<% fields_for :x do |f| %>` rendered its block by accident; it now renders nothing, without raising an error. Change those tags to `<%= fields_for :x do |f| %>` when upgrading. This change can't be made before upgrading: plain `ERB` raises a syntax error on `<%= helper do %>`.
- Subtemplates are compiled with the ActionView handler registered for their extension, the same way ViewComponent compiles the main template. Block helpers (`<%= content_tag :div do %>`) and `capture` now work inside subtemplates, and `.haml`/`.slim` subtemplates use their own handler instead of being compiled as ERB.
- The trim marker in `<%# locals: (...) -%>` now removes the line break that follows it, so subtemplate output no longer starts with `"\n"`.
- Subtemplates in a non-HTML format (e.g. `notes.text.erb`) are not HTML-escaped, following Rails' behavior for text templates. Their output is not marked `html_safe`, so it is escaped when embedded in an HTML template.

## [0.3.0] - 2026-06-12

### Added
- `render_subtemplate_in(view_context, name)` to render a single subtemplate on its own, from outside the component (e.g. a controller responding with just a fragment), without rendering the main template. It is the subtemplate-level counterpart of ViewComponent's `render_in`. The subtemplate must not declare locals (per-render data is passed through the component's constructor); rendering a subtemplate with locals, or one that is not defined, raises a clear error.

## [0.2.0] - 2026-01-21

### Added
- Automatic subtemplate processing for ancestor components
- Support for multi-level inheritance (grandparent → parent → child)

### Fixed
- Inheritance issue where child components miss parent's `call_*` methods

## [0.1.1] - 2026-01-13

### Changed
- Use official `after_compile` hook from ViewComponent 4.2.0 via `ActiveSupport.on_load(:view_component)`
- Expanded test matrix to Ruby 3.2, 3.3, and 3.4

### Fixed
- Rubocop offenses

## [0.1.0] - 2025-07-18

### Agregado
- Implementación inicial del soporte para sub-templates en ViewComponent usando archivos sidecar
- Añadido el DSL `template_arguments` para definir argumentos en sub-templates
- Generación dinámica de métodos `call_*` para sub-templates con validación estricta de argumentos
- Integración con el flujo de compilación de ViewComponent

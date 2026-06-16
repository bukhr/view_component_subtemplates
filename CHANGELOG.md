## [Unreleased]

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

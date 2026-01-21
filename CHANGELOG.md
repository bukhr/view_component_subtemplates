## [Unreleased]

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

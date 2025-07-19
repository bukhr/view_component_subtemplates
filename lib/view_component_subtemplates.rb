# view_component_subtemplates.rb
# frozen_string_literal: true

require "view_component"

# Forzar carga de ViewComponent internals
begin
  require "view_component/template"
rescue LoadError
  # En versiones más antiguas, Template podría estar en otro lugar
  begin
    require "view_component/base"
    require "view_component/compiler"
  rescue LoadError
    # Fallback - cargar ViewComponent completo
  end
end

require_relative "view_component_subtemplates/version"
require_relative "view_component_subtemplates/compiler_extension"

module ViewComponentSubtemplates
  class Error < StandardError; end

  def self.sub_template_path_for(component_class, template_name)
    component_dir = File.dirname(component_class.identifier)
    component_name = component_class.name.demodulize.underscore
    File.join(component_dir, component_name, "#{template_name}.html.erb")
  end

  def self.component_subdir_for(component_class)
    component_dir = File.dirname(component_class.identifier)
    component_name = component_class.name.demodulize.underscore
    File.join(component_dir, component_name)
  end
end

# Cargar SubTemplate DESPUÉS de que todo esté configurado
require_relative "view_component_subtemplates/sub_template"

# Extend ViewComponent::Base to add after_compile hook for sub-templates
ViewComponent::Base.class_eval do
  def after_compile
    super if defined?(super)
    ViewComponentSubtemplates::CompilerExtension.process_component(self.class)
  end
end

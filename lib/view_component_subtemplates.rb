# view_component_subtemplates.rb
# frozen_string_literal: true

require "active_support"

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

  # Module to extend ViewComponent::Base class methods
  # This hooks into the after_compile class method from ViewComponent PR #2411
  module AfterCompileHook
    def after_compile
      super
      ViewComponentSubtemplates::CompilerExtension.process_component(self)
    end
  end
end

# Load SubTemplate after the module is fully configured
require_relative "view_component_subtemplates/sub_template"

# Hook into ViewComponent when it loads (lazy loading for faster boot in development)
ActiveSupport.on_load(:view_component) do
  ViewComponent::Base.singleton_class.prepend(ViewComponentSubtemplates::AfterCompileHook)
end

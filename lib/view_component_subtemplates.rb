# view_component_subtemplates.rb
# frozen_string_literal: true

require "view_component"

# Ensure ViewComponent internals are loaded
require "view_component/base"
require "view_component/compiler"

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

# Extend ViewComponent::Base class methods to hook into after_compile
# This uses prepend on the singleton class to extend the class method
ViewComponent::Base.singleton_class.prepend(ViewComponentSubtemplates::AfterCompileHook)

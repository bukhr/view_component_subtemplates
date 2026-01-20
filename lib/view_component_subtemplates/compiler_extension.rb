# frozen_string_literal: true

module ViewComponentSubtemplates
  # Extends ViewComponent's compilation process to handle subtemplates.
  module CompilerExtension
    # Compiles all subtemplates for a component into call_* methods.
    # Skips processing if already done for this component.
    #
    # @param component_class [Class] the component class to process
    # @return [void]
    def self.process_component(component_class)
      return if component_class.instance_variable_get(:@__subtemplates_processed)

      gather_sub_templates_for(component_class).each(&:compile_to_component)
      component_class.instance_variable_set(:@__subtemplates_processed, true)
    end

    # Discovers subtemplate files in the component's subdirectory.
    #
    # @param component_class [Class] the component class
    # @return [Array<SubTemplate>] array of subtemplate objects
    def self.gather_sub_templates_for(component_class)
      component_subdir = ViewComponentSubtemplates.component_subdir_for(component_class)
      return [] unless Dir.exist?(component_subdir)

      template_extensions = ActionView::Template.template_handler_extensions

      Dir.glob(File.join(component_subdir, "*")).filter_map do |file_path|
        next unless File.file?(file_path)
        next unless template_extensions.include?(File.extname(file_path)[1..])

        template_name = File.basename(file_path).split(".").first

        SubTemplate.new(
          component: component_class,
          path: file_path,
          template_name: template_name
        )
      end
    end
  end
end

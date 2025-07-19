# compiler_extension.rb
module ViewComponentSubtemplates
  module CompilerExtension
    # Método estático para procesar componentes usando el hook after_compile
    def self.process_component(component_class)
      gather_sub_templates_for(component_class).each do |sub_template|
        sub_template.compile_to_component
      end
    end

    private

    def self.gather_sub_templates_for(component_class)
      component_subdir = ViewComponentSubtemplates.component_subdir_for(component_class)
      return [] unless Dir.exist?(component_subdir)

      template_extensions = ActionView::Template.template_handler_extensions
      
      Dir.glob(File.join(component_subdir, "*")).filter_map do |file_path|
        next unless File.file?(file_path)
        
        file_extension = File.extname(file_path)[1..] # Remove the leading dot
        next unless template_extensions.include?(file_extension)
        
        # Correctly extract template name by removing the first extension found.
        # e.g. "header.html.erb" -> "header"
        template_name = File.basename(file_path).split('.').first
        
        SubTemplate.new(
          component: component_class,
          path: file_path,
          template_name: template_name
        )
      end
    end
  end
end

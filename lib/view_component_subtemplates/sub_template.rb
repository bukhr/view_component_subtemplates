# frozen_string_literal: true

# sub_template.rb
module ViewComponentSubtemplates
  # Represents a single sub-template file associated with a ViewComponent.
  # This class is responsible for parsing the template, extracting its arguments,
  # and defining the corresponding `call_*` method on the component class.
  #
  # PUBLIC API - The following methods are guaranteed to be stable across minor versions:
  # - #component:       Returns the associated component class.
  # - #path:             Returns the absolute path to the template file.
  # - #template_name:    Returns the short name of the template (e.g., `header`).
  # - #explicit_locals:  Returns an array of symbols for the template's arguments.
  # - #source:           Returns the raw source code of the template file.
  #
  # PRIVATE API - All other methods are subject to change without notice.
  class SubTemplate
    # Minimal template object accepted by ActionView template handlers.
    TemplateDetails = Struct.new(:format, :identifier, :short_identifier, :type, keyword_init: true)
    private_constant :TemplateDetails

    # PUBLIC API
    attr_reader :component, :path, :template_name

    def initialize(component:, path:, template_name:)
      @component = component
      @path = path
      @template_name = template_name
      @source = nil # Lazily loaded
      @explicit_locals = nil # Lazily loaded
    end

    def source
      @source ||= File.read(path)
    end

    def explicit_locals
      @explicit_locals ||= extract_explicit_locals_from_source
    end

    # This is the main entry point for the class from the compiler extension
    def compile_to_component
      validate_file_exists!
      compiled_source = compile_source
      define_render_method(compiled_source, explicit_locals)
    end

    private

    def validate_file_exists!
      return if File.exist?(path)

      raise ViewComponentSubtemplates::Error, "Template file not found: #{path}"
    end

    def extract_explicit_locals_from_source
      match = source.match(/<%#\s*locals:\s*\((.*?)\)\s*-%>/)
      return [] unless match

      locals_string = match[1]
      locals_string.scan(/(\w+):/).flatten.map(&:to_sym)
    end

    # Compiles the source with the ActionView handler registered for the file
    # extension, the same way ViewComponent compiles the main template. This keeps
    # Rails' HTML escaping for `<%= %>` and support for block helpers and capture.
    def compile_source
      template = TemplateDetails.new(
        format: template_format,
        identifier: path,
        short_identifier: short_identifier,
        type: template_type
      )

      template_handler.call(template, source)
    end

    def template_type
      ActionView::Template::Types[template_format]
    end

    def escaped_output?
      !ActionView::Template::Handlers::ERB.escape_ignore_list.include?(template_type)
    end

    def template_handler
      extension = File.basename(path).split(".").last
      ActionView::Template.registered_template_handler(extension)
    end

    def template_format
      parts = File.basename(path).split(".")
      parts.length > 2 ? parts[-2].to_sym : :html
    end

    def short_identifier
      defined?(Rails.root) && Rails.root ? path.sub("#{Rails.root}/", "") : path
    end

    def define_render_method(compiled_source, expected_args)
      render_method_name = "__render_sub_template_#{template_name}"
      call_method_name = "call_#{template_name}"

      define_private_render_method(render_method_name, compiled_source, expected_args)
      define_public_call_method(call_method_name, render_method_name, expected_args)
    end

    # `capture` renders into a fresh string inside the shared buffer, not the
    # caller's output. ViewComponent's override syncs it with the view context's
    # buffer (they differ inside partials), so `helpers` blocks capture correctly.
    # It returns nil for an empty subtemplate.
    def define_private_render_method(name, compiled_source, args)
      output = escaped_output? ? "output" : "String.new(output)"

      @component.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        private
        def #{name}(#{args.join(", ")})
          output = capture { #{compiled_source} } || "".html_safe
          #{output}
        end
      RUBY
    end

    def define_public_call_method(call_name, render_name, args)
      @component.silence_redefinition_of_method(call_name.to_sym)

      if args.any?
        signature = args.map { |arg| "#{arg}:" }.join(", ")
        forwarded_args = args.join(", ")

        @component.class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{call_name}(#{signature})
            #{render_name}(#{forwarded_args})
          end
        RUBY
      else
        @component.class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{call_name}
            #{render_name}
          end
        RUBY
      end
    end
  end
end

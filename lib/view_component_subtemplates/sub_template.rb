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
      compiled_source = compile_erb_source
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

    def compile_erb_source
      erb = ERB.new(source)
      erb.filename = path
      erb.src
    end

    def define_render_method(compiled_source, expected_args)
      render_method_name = "__render_sub_template_#{template_name}"
      call_method_name = "call_#{template_name}"

      define_private_render_method(render_method_name, compiled_source, expected_args)
      define_public_call_method(call_method_name, render_method_name, expected_args)
    end

    def define_private_render_method(name, compiled_source, args)
      @component.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        private
        def #{name}(#{args.join(", ")})
          (#{compiled_source}).html_safe
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

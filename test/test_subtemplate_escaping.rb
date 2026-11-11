# frozen_string_literal: true

require "test_helper"

class TestSubtemplateEscaping < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @component_class = Class.new(ViewComponent::Base) { attr_writer :value }
    Object.const_set(:EscapingComponent, @component_class)
    @component_dir = File.join(@temp_dir, "escaping_component")
    Dir.mkdir(@component_dir)
    temp_dir = @temp_dir
    @component_class.define_singleton_method(:identifier) { File.join(temp_dir, "escaping_component.rb") }
    File.write(File.join(@temp_dir, "escaping_component.html.erb"), "<main>Main</main>")
  end

  def teardown
    Object.send(:remove_const, :EscapingComponent) if Object.const_defined?(:EscapingComponent)
    FileUtils.rm_rf(@temp_dir) if @temp_dir
  end

  def test_escapes_interpolated_text_and_preserves_static_markup
    component = compile_templates(body: "<%# locals: (value:) -%><p><%= value %></p>")

    result = component.call_body(value: "<strong>POC & \"quoted\" 'text'</strong>")

    assert_equal "<p>&lt;strong&gt;POC &amp; &quot;quoted&quot; &#39;text&#39;&lt;/strong&gt;</p>", result
    assert result.html_safe?
  end

  def test_escapes_quotes_in_interpolated_attributes
    component = compile_templates(field: '<%# locals: (value:) -%><input value="<%= value %>">')

    result = component.call_field(value: '" autofocus onfocus="alert(1)')

    assert_equal '<input value="&quot; autofocus onfocus=&quot;alert(1)">', result
  end

  def test_preserves_html_safe_values
    component = compile_templates(body: "<%# locals: (value:) -%><p><%= value %></p>")

    result = component.call_body(value: "<strong>Trusted</strong>".html_safe)

    assert_equal "<p><strong>Trusted</strong></p>", result
  end

  def test_preserves_safe_helper_output_without_double_escaping
    component = compile_templates(body: '<%= helpers.content_tag(:strong, "<untrusted>") %>')

    result = component.render_subtemplate_in(view_context, :body)

    assert_equal "<strong>&lt;untrusted&gt;</strong>", result
  end

  def test_renders_escaped_subtemplate_once_inside_the_main_template
    File.write(File.join(@temp_dir, "escaping_component.html.erb"), "<main><%= call_body %></main>")
    component = compile_templates(body: "<strong><%= @value %></strong>")
    component.value = "<untrusted>"

    result = component.render_in(view_context)

    assert_equal "<main><strong>&lt;untrusted&gt;</strong></main>", result
  end

  def test_does_not_double_escape_nested_subtemplates
    component = compile_templates(
      inner: "<%# locals: (value:) -%><strong><%= value %></strong>",
      outer: "<%# locals: (value:) -%><section><%= call_inner(value: value) %></section>"
    )

    result = component.call_outer(value: "<untrusted>")

    assert_equal "<section><strong>&lt;untrusted&gt;</strong></section>", result
  end

  def test_escapes_instance_state_when_rendered_standalone
    component = compile_templates(body: "<p><%= @value %></p>")
    component.value = "<strong>POC</strong>"

    result = component.render_subtemplate_in(view_context, :body)

    assert_equal "<p>&lt;strong&gt;POC&lt;/strong&gt;</p>", result
  end

  def test_preserves_nil_numeric_and_boolean_values_in_loops
    component = compile_templates(
      body: "<%# locals: (values:) -%><ul><% values.each do |value| %><li><%= value %></li><% end %></ul>"
    )

    result = component.call_body(values: [nil, 65, 1.5, true, false, "<untrusted>"])

    assert_equal "<ul><li></li><li>65</li><li>1.5</li><li>true</li><li>false</li>" \
                 "<li>&lt;untrusted&gt;</li></ul>", result
  end

  def test_escapes_objects_after_string_conversion
    component = compile_templates(body: "<%# locals: (value:) -%><p><%= value %></p>")
    value = Object.new
    value.define_singleton_method(:to_s) { "<strong>POC</strong>" }

    assert_equal "<p>&lt;strong&gt;POC&lt;/strong&gt;</p>", component.call_body(value: value)
  end

  def test_preserves_postfix_conditionals
    component = compile_templates(body: "<%# locals: (value:, show:) -%><p><%= value if show %></p>")

    assert_equal "<p>&lt;untrusted&gt;</p>", component.call_body(value: "<untrusted>", show: true)
    assert_equal "<p></p>", component.call_body(value: "<untrusted>", show: false)
  end

  private

  def compile_templates(templates)
    templates.each do |name, source|
      File.write(File.join(@component_dir, "#{name}.html.erb"), source)
    end
    ViewComponent::Compiler.new(@component_class).compile(force: true)
    @component_class.new
  end

  def view_context
    ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil)
  end
end

# frozen_string_literal: true

require "test_helper"
require "ostruct"

class TestViewComponentSubtemplates < Minitest::Test
  context "call method generation with explicit locals" do
    setup do
      @component_class = Class.new(ViewComponent::Base)
      Object.const_set(:TestCallComponent, @component_class)
      @temp_dir = Dir.mktmpdir
      @component_dir = File.join(@temp_dir, "test_call_component")
      Dir.mkdir(@component_dir)
      temp_dir = @temp_dir
      @component_class.define_singleton_method(:identifier) do
        File.join(temp_dir, "test_call_component.rb")
      end

      # Templates con explicit locals
      File.write(File.join(@component_dir, "row.html.erb"),
                 "<%# locals: (model:) -%>\n<tr><td><%= model %></td></tr>")
      File.write(File.join(@component_dir, "header.html.erb"),
                 "<%# locals: (title:) -%>\n<th><%= title %></th>")
    end

    teardown do
      Object.send(:remove_const, :TestCallComponent) if Object.const_defined?(:TestCallComponent)
      FileUtils.rm_rf(@temp_dir) if @temp_dir
    end

    # Add a main template to satisfy the real compiler
    setup do
      File.write(File.join(@temp_dir, "test_call_component.html.erb"), "<div>Main</div>")
    end

    should "define call methods dynamically and correctly" do
      ViewComponent::Compiler.new(@component_class).compile(force: true)

      assert @component_class.instance_methods.include?(:call_row)
      assert @component_class.instance_methods.include?(:call_header)

      component = @component_class.new
      result = component.call_row(model: "test")

      assert_equal "\n<tr><td>test</td></tr>", result
    end

    should "make call methods respond to respond_to?" do
      ViewComponent::Compiler.new(@component_class).compile(force: true)
      component = @component_class.new

      assert component.respond_to?(:call_row)
    end

    should "pass keyword arguments correctly" do
      ViewComponent::Compiler.new(@component_class).compile(force: true)
      component = @component_class.new
      result = component.call_header(title: "Test Title")

      assert_equal "\n<th>Test Title</th>", result
    end

    should "validate required arguments strictly" do
      ViewComponent::Compiler.new(@component_class).compile(force: true)
      component = @component_class.new

      error = assert_raises(ArgumentError) { component.call_row }
      assert_match(/missing keyword/, error.message)

      error = assert_raises(ArgumentError) { component.call_row(model: "test", extra_param: "ignored") }
      assert_match(/unknown keyword/, error.message)
    end

    should "generate call method for template without arguments" do
      File.write(File.join(@component_dir, "footer.html.erb"), "<footer>Footer content</footer>")
      ViewComponent::Compiler.new(@component_class).compile(force: true)

      component = @component_class.new
      result = component.call_footer

      assert_equal "<footer>Footer content</footer>", result
    end

    should "return html_safe strings from call methods" do
      ViewComponent::Compiler.new(@component_class).compile(force: true)
      component = @component_class.new
      result = component.call_row(model: "test")

      assert result.html_safe?
    end
  end

  context "compiler extension" do
    setup do
      @component_class = Class.new(ViewComponent::Base)
      Object.const_set(:TestCompilerComponent, @component_class)
      @temp_dir = Dir.mktmpdir
      @component_dir = File.join(@temp_dir, "test_compiler_component")
      Dir.mkdir(@component_dir)
      temp_dir = @temp_dir
      @component_class.define_singleton_method(:identifier) do
        File.join(temp_dir, "test_compiler_component.rb")
      end
    end

    teardown do
      Object.send(:remove_const, :TestCompilerComponent) if Object.const_defined?(:TestCompilerComponent)
      FileUtils.rm_rf(@temp_dir) if @temp_dir
    end

    # This setup requires a main template file to avoid `TemplateError` in the real compiler
    setup do
      File.write(File.join(@temp_dir, "test_compiler_component.html.erb"), "<div>Main</div>")
    end

    should "not define any call methods when no sub-templates exist" do
      # No sub-templates created
      ViewComponent::Compiler.new(@component_class).compile(force: true)

      instance = @component_class.new
      call_methods = instance.methods.grep(/^call_/)
      assert_empty call_methods, "Expected no call_* methods to be defined"
    end

    should "define call methods for all sub-templates" do
      File.write(File.join(@component_dir, "row.html.erb"), "<tr></tr>")
      File.write(File.join(@component_dir, "header.html.erb"), "<th></th>")

      ViewComponent::Compiler.new(@component_class).compile(force: true)

      instance = @component_class.new
      assert instance.respond_to?(:call_row), "Expected component to respond to call_row"
      assert instance.respond_to?(:call_header), "Expected component to respond to call_header"
    end

    should "ignore non-template files and define methods only for templates" do
      File.write(File.join(@component_dir, "row.html.erb"), "<tr></tr>")
      File.write(File.join(@component_dir, "README.md"), "# Documentation")
      File.write(File.join(@component_dir, "styles.css"), "/* styles */")

      ViewComponent::Compiler.new(@component_class).compile(force: true)

      instance = @component_class.new
      assert instance.respond_to?(:call_row)
      assert !instance.respond_to?(:call_README)
      assert !instance.respond_to?(:call_styles)
    end

    should "define call methods for different template extensions" do
      File.write(File.join(@component_dir, "erb_template.html.erb"), "<div>ERB</div>")
      File.write(File.join(@component_dir, "haml_template.html.haml"), "%div HAML") if defined?(Haml)
      File.write(File.join(@component_dir, "slim_template.html.slim"), "div SLIM") if defined?(Slim)

      ViewComponent::Compiler.new(@component_class).compile(force: true)

      instance = @component_class.new
      assert instance.respond_to?(:call_erb_template)
      assert instance.respond_to?(:call_haml_template) if defined?(Haml)
      assert instance.respond_to?(:call_slim_template) if defined?(Slim)
    end
  end

  context "SubTemplate public API" do
    setup do
      @component_class = Class.new(ViewComponent::Base)
      @temp_file = Tempfile.new(["test", ".html.erb"])
    end

    teardown do
      @temp_file&.unlink
    end

    should "expose public attributes" do
      @temp_file.write("API test")
      @temp_file.close

      sub_template = ViewComponentSubtemplates::SubTemplate.new(
        component: @component_class,
        path: @temp_file.path,
        template_name: :my_template
      )

      assert_equal @component_class, sub_template.component
      assert_equal @temp_file.path, sub_template.path
      assert_equal :my_template, sub_template.template_name
      assert_equal "API test", sub_template.source
    end

    should "correctly extract explicit_locals via the public API" do
      @temp_file.write("<%# locals: (name:, age:) -%>\n<div>Content</div>")
      @temp_file.close

      sub_template = ViewComponentSubtemplates::SubTemplate.new(
        component: @component_class,
        path: @temp_file.path,
        template_name: :test
      )

      assert_equal %i[name age], sub_template.explicit_locals
    end

    should "return empty array for explicit_locals when none are defined" do
      @temp_file.write("<div>No locals</div>")
      @temp_file.close

      sub_template = ViewComponentSubtemplates::SubTemplate.new(
        component: @component_class,
        path: @temp_file.path,
        template_name: :test
      )

      assert_equal [], sub_template.explicit_locals
    end
  end

  context "integration with real components" do
    setup do
      @table_component = Class.new(ViewComponent::Base) do
        def initialize(items:, columns: [])
          @items = items
          @columns = columns
        end

        def call
          content_tag :table do
            safe_join([
                        content_tag(:thead, call_header(columns: @columns)),
                        content_tag(:tbody,
                                    safe_join(@items.map.with_index do |item, idx|
                                      call_row(item: item, index: idx)
                                    end))
                      ])
          end
        end
      end

      Object.const_set(:TableComponent, @table_component)
      @temp_dir = Dir.mktmpdir
      @component_dir = File.join(@temp_dir, "table_component")
      Dir.mkdir(@component_dir)
      temp_dir = @temp_dir
      @table_component.define_singleton_method(:identifier) do
        File.join(temp_dir, "table_component.rb")
      end

      # Templates con explicit locals
      File.write(File.join(@component_dir, "row.html.erb"),
                 "<%# locals: (item:, index:) -%>\n<tr data-index='<%= index %>'><td><%= item[:name] %></td></tr>")
      File.write(File.join(@component_dir, "header.html.erb"),
                 "<%# locals: (columns:) -%>\n<tr><% columns.each do |col| %><th><%= col %></th><% end %></tr>")
    end

    teardown do
      Object.send(:remove_const, :TableComponent) if Object.const_defined?(:TableComponent)
      FileUtils.rm_rf(@temp_dir) if @temp_dir
    end

    should "work in a real component scenario" do
      ViewComponent::Compiler.new(@table_component).compile

      items = [
        { name: "Item 1" },
        { name: "Item 2" }
      ]
      component = @table_component.new(items: items, columns: ["Name"])

      # Simulate ViewComponent rendering context
      view_context = ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil)
      component.set_original_view_context(view_context)

      result = component.call

      assert_includes result, "<table>"
      assert_includes result, "<thead>"
      assert_includes result, "<tbody>"
      assert_includes result, "data-index='0'"
      assert_includes result, "Item 1"
      assert_includes result, "Item 2"
    end
  end

  context "component inheritance with subtemplates" do
    setup do
      @temp_dir = Dir.mktmpdir

      # Create parent component
      @parent_component = Class.new(ViewComponent::Base)
      Object.const_set(:ParentComponent, @parent_component)
      @parent_dir = File.join(@temp_dir, "parent_component")
      Dir.mkdir(@parent_dir)

      temp_dir = @temp_dir
      @parent_component.define_singleton_method(:identifier) do
        File.join(temp_dir, "parent_component.rb")
      end

      # Create parent main template
      File.write(File.join(@temp_dir, "parent_component.html.erb"), "<div>Parent</div>")

      # Create parent subtemplates
      File.write(File.join(@parent_dir, "header.html.erb"),
                 "<%# locals: (title:) -%>\n<h1><%= title %></h1>")
      File.write(File.join(@parent_dir, "footer.html.erb"),
                 "<footer>Parent Footer</footer>")
    end

    teardown do
      Object.send(:remove_const, :ParentComponent) if Object.const_defined?(:ParentComponent)
      Object.send(:remove_const, :ChildComponent) if Object.const_defined?(:ChildComponent)
      FileUtils.rm_rf(@temp_dir) if @temp_dir
    end

    should "inherit call methods from parent component" do
      # Compile parent first
      ViewComponent::Compiler.new(@parent_component).compile

      # Create child component that inherits from parent
      child_component = Class.new(@parent_component)
      Object.const_set(:ChildComponent, child_component)
      temp_dir = @temp_dir
      child_component.define_singleton_method(:identifier) do
        File.join(temp_dir, "child_component.rb")
      end

      # Create child main template
      File.write(File.join(@temp_dir, "child_component.html.erb"), "<div>Child</div>")

      # Compile child
      ViewComponent::Compiler.new(child_component).compile

      # Child should inherit parent's call methods
      child_instance = child_component.new
      assert child_instance.respond_to?(:call_header)
      assert child_instance.respond_to?(:call_footer)

      result = child_instance.call_header(title: "Inherited Title")
      assert_equal "\n<h1>Inherited Title</h1>", result
    end

    should "automatically compile parent when child is compiled first" do
      # Create child component BEFORE parent is compiled
      child_component = Class.new(@parent_component)
      Object.const_set(:ChildComponent, child_component)
      temp_dir = @temp_dir
      child_component.define_singleton_method(:identifier) do
        File.join(temp_dir, "child_component.rb")
      end

      # Create child main template
      File.write(File.join(@temp_dir, "child_component.html.erb"), "<div>Child</div>")

      # Compile child FIRST (parent not compiled yet)
      ViewComponent::Compiler.new(child_component).compile

      # Child should still have access to parent's call methods
      child_instance = child_component.new
      assert child_instance.respond_to?(:call_header), "Child should inherit call_header from parent"
      assert child_instance.respond_to?(:call_footer), "Child should inherit call_footer from parent"

      result = child_instance.call_header(title: "Auto-compiled Parent")
      assert_equal "\n<h1>Auto-compiled Parent</h1>", result
    end

    should "work with child that has its own subtemplates" do
      # Create child with its own subtemplates
      child_component = Class.new(@parent_component)
      Object.const_set(:ChildComponent, child_component)
      child_dir = File.join(@temp_dir, "child_component")
      Dir.mkdir(child_dir)

      temp_dir = @temp_dir
      child_component.define_singleton_method(:identifier) do
        File.join(temp_dir, "child_component.rb")
      end

      # Create child main template
      File.write(File.join(@temp_dir, "child_component.html.erb"), "<div>Child</div>")

      # Create child subtemplates
      File.write(File.join(child_dir, "body.html.erb"),
                 "<%# locals: (content:) -%>\n<main><%= content %></main>")

      # Compile child
      ViewComponent::Compiler.new(child_component).compile

      child_instance = child_component.new

      # Should have both parent and child call methods
      assert child_instance.respond_to?(:call_header), "Should have parent's call_header"
      assert child_instance.respond_to?(:call_footer), "Should have parent's call_footer"
      assert child_instance.respond_to?(:call_body), "Should have child's call_body"

      parent_result = child_instance.call_header(title: "Test")
      assert_equal "\n<h1>Test</h1>", parent_result

      child_result = child_instance.call_body(content: "Child content")
      assert_equal "\n<main>Child content</main>", child_result
    end

    should "skip ancestor compilation for direct ViewComponent::Base children" do
      # Component inherits directly from ViewComponent::Base (no custom parent)
      direct_child = Class.new(ViewComponent::Base)
      Object.const_set(:DirectChild, direct_child)
      direct_child_dir = File.join(@temp_dir, "direct_child")
      Dir.mkdir(direct_child_dir)

      temp_dir = @temp_dir
      direct_child.define_singleton_method(:identifier) do
        File.join(temp_dir, "direct_child.rb")
      end

      File.write(File.join(@temp_dir, "direct_child.html.erb"), "<div>Direct</div>")
      File.write(File.join(direct_child_dir, "nav.html.erb"),
                 "<%# locals: (items:) -%>\n<nav><%= items.join(', ') %></nav>")

      # Should compile and process its own subtemplates
      ViewComponent::Compiler.new(direct_child).compile

      direct_child_instance = direct_child.new
      assert direct_child_instance.respond_to?(:call_nav), "Should have its own call_nav method"

      result = direct_child_instance.call_nav(items: %w[Home About])
      assert_equal "\n<nav>Home, About</nav>", result
    ensure
      Object.send(:remove_const, :DirectChild) if Object.const_defined?(:DirectChild)
    end

    should "not reprocess subtemplates if already processed" do
      # Compile parent first
      ViewComponent::Compiler.new(@parent_component).compile

      # Verify parent was marked as processed
      assert @parent_component.instance_variable_get(:@__subtemplates_processed),
             "Parent should be marked as processed"

      # Create and compile child
      child_component = Class.new(@parent_component)
      Object.const_set(:ChildComponent, child_component)
      temp_dir = @temp_dir
      child_component.define_singleton_method(:identifier) do
        File.join(temp_dir, "child_component.rb")
      end
      File.write(File.join(@temp_dir, "child_component.html.erb"), "<div>Child</div>")

      # Compile child - parent subtemplates should NOT be reprocessed
      ViewComponent::Compiler.new(child_component).compile

      # Both should work correctly
      child_instance = child_component.new
      assert child_instance.respond_to?(:call_header)
      assert child_instance.respond_to?(:call_footer)

      result = child_instance.call_header(title: "No Reprocess")
      assert_equal "\n<h1>No Reprocess</h1>", result
    end

    should "handle multi-level inheritance (3+ levels)" do
      # Create grandparent component with subtemplates
      grandparent_component = Class.new(ViewComponent::Base)
      Object.const_set(:GrandparentComponent, grandparent_component)
      grandparent_dir = File.join(@temp_dir, "grandparent_component")
      Dir.mkdir(grandparent_dir)

      temp_dir = @temp_dir
      grandparent_component.define_singleton_method(:identifier) do
        File.join(temp_dir, "grandparent_component.rb")
      end

      # Create grandparent main template and subtemplates
      File.write(File.join(@temp_dir, "grandparent_component.html.erb"), "<div>Grandparent</div>")
      File.write(File.join(grandparent_dir, "title.html.erb"),
                 "<%# locals: (text:) -%>\n<h1><%= text %></h1>")

      # Create parent component (inherits from grandparent, no subtemplates)
      parent_component = Class.new(grandparent_component)
      Object.const_set(:MiddleParentComponent, parent_component)
      parent_component.define_singleton_method(:identifier) do
        File.join(temp_dir, "middle_parent_component.rb")
      end
      File.write(File.join(@temp_dir, "middle_parent_component.html.erb"), "<div>Parent</div>")

      # Create child component (inherits from parent)
      child_component = Class.new(parent_component)
      Object.const_set(:GrandchildComponent, child_component)
      child_component.define_singleton_method(:identifier) do
        File.join(temp_dir, "grandchild_component.rb")
      end
      File.write(File.join(@temp_dir, "grandchild_component.html.erb"), "<div>Grandchild</div>")

      # Compile ONLY the grandchild (not grandparent or parent)
      ViewComponent::Compiler.new(child_component).compile

      # Grandchild should inherit call_title from grandparent
      child_instance = child_component.new
      assert child_instance.respond_to?(:call_title), "Grandchild should inherit call_title from grandparent"

      result = child_instance.call_title(text: "Multi-level Title")
      assert_equal "\n<h1>Multi-level Title</h1>", result
    ensure
      Object.send(:remove_const, :GrandparentComponent) if Object.const_defined?(:GrandparentComponent)
      Object.send(:remove_const, :MiddleParentComponent) if Object.const_defined?(:MiddleParentComponent)
      Object.send(:remove_const, :GrandchildComponent) if Object.const_defined?(:GrandchildComponent)
    end

    should "compile all ancestors with subtemplates even if middle parent already compiled" do
      # This test exposes the bug where middle parent is already compiled
      # but grandparent is not, so we need to walk the entire chain

      # Create grandparent component with subtemplates
      grandparent_component = Class.new(ViewComponent::Base)
      Object.const_set(:GrandParent2, grandparent_component)
      grandparent_dir = File.join(@temp_dir, "grand_parent2")
      Dir.mkdir(grandparent_dir)

      temp_dir = @temp_dir
      grandparent_component.define_singleton_method(:identifier) do
        File.join(temp_dir, "grand_parent2.rb")
      end

      File.write(File.join(@temp_dir, "grand_parent2.html.erb"), "<div>GP2</div>")
      File.write(File.join(grandparent_dir, "banner.html.erb"),
                 "<%# locals: (msg:) -%>\n<div class='banner'><%= msg %></div>")

      # Create middle parent (no subtemplates)
      middle_component = Class.new(grandparent_component)
      Object.const_set(:MiddleParent2, middle_component)
      middle_component.define_singleton_method(:identifier) do
        File.join(temp_dir, "middle_parent2.rb")
      end
      File.write(File.join(@temp_dir, "middle_parent2.html.erb"), "<div>Middle2</div>")

      # Compile middle parent FIRST (grandparent NOT compiled yet)
      ViewComponent::Compiler.new(middle_component).compile

      # Now create and compile grandchild
      child_component = Class.new(middle_component)
      Object.const_set(:GrandChild2, child_component)
      child_component.define_singleton_method(:identifier) do
        File.join(temp_dir, "grand_child2.rb")
      end
      File.write(File.join(@temp_dir, "grand_child2.html.erb"), "<div>GC2</div>")

      # Compile grandchild - should detect grandparent has subtemplates and compile it
      ViewComponent::Compiler.new(child_component).compile

      # Grandchild should have call_banner from grandparent
      child_instance = child_component.new
      assert child_instance.respond_to?(:call_banner),
             "Grandchild should inherit call_banner even when middle parent was pre-compiled"

      result = child_instance.call_banner(msg: "Success!")
      assert_equal "\n<div class='banner'>Success!</div>", result
    ensure
      Object.send(:remove_const, :GrandParent2) if Object.const_defined?(:GrandParent2)
      Object.send(:remove_const, :MiddleParent2) if Object.const_defined?(:MiddleParent2)
      Object.send(:remove_const, :GrandChild2) if Object.const_defined?(:GrandChild2)
    end
  end

  context "error handling" do
    setup do
      @component_class = Class.new(ViewComponent::Base)
      Object.const_set(:ErrorComponent, @component_class)
      @temp_dir = Dir.mktmpdir
      @component_dir = File.join(@temp_dir, "error_component")
      Dir.mkdir(@component_dir)
      temp_dir = @temp_dir
      @component_class.define_singleton_method(:identifier) do
        File.join(temp_dir, "error_component.rb")
      end
    end

    teardown do
      Object.send(:remove_const, :ErrorComponent) if Object.const_defined?(:ErrorComponent)
      FileUtils.rm_rf(@temp_dir) if @temp_dir
    end

    should "handle missing template file gracefully" do
      # Crear un SubTemplate con un path que no existe
      sub_template = ViewComponentSubtemplates::SubTemplate.new(
        component: @component_class,
        path: File.join(@component_dir, "missing.html.erb"),
        template_name: :missing
      )

      error = assert_raises(ViewComponentSubtemplates::Error) do
        sub_template.compile_to_component
      end

      assert_match(/Template file not found/, error.message)
    end

    should "handle template with undefined variables" do
      # Template sin locals pero usa una variable
      File.write(File.join(@component_dir, "broken.html.erb"), "<%= undefined_variable %>")

      ViewComponent::Compiler.new(@component_class).compile
      component = @component_class.new

      # Should raise when calling the method, not during compilation
      assert_raises(NameError) do
        component.call_broken # Sin argumentos porque no hay locals definidos
      end
    end

    should "handle template with mismatched locals" do
      # Template con locals pero usa variable no declarada
      File.write(File.join(@component_dir, "mismatch.html.erb"),
                 "<%# locals: (declared_var:) -%>\n<%= undeclared_var %>")

      ViewComponent::Compiler.new(@component_class).compile
      component = @component_class.new

      assert_raises(NameError) do
        component.call_mismatch(declared_var: "test")
      end
    end
  end
end

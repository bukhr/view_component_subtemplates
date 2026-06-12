# frozen_string_literal: true

module ViewComponentSubtemplates
  # Renders one subtemplate on its own (no main template), e.g. to serve a fragment
  # from a controller. The subtemplate-level counterpart of `render_in`.
  # Requires a no-locals subtemplate: per-render data goes through the constructor.
  module StandaloneRenderer
    # @param view_context [ActionView::Base] inside a controller, this is `view_context`.
    # @param name [Symbol, String] subtemplate name, without the `call_` prefix.
    # @return [String] the subtemplate's HTML (html_safe).
    def render_subtemplate_in(view_context, name)
      self.class.__vc_compile(raise_errors: true)
      ensure_renderable_subtemplate!(name)

      # Set up the view context the helper guards require. `__vc_original_view_context`
      # makes `helpers` reuse it instead of building a new one (keep both).
      @view_context = view_context
      self.__vc_original_view_context = view_context

      public_send("call_#{name}")
    end

    private

    def ensure_renderable_subtemplate!(name)
      call_method = "call_#{name}"
      unless respond_to?(call_method)
        raise ViewComponentSubtemplates::Error,
              "Subtemplate `#{name}` is not defined on #{self.class}. " \
              "Available subtemplates: #{available_subtemplates.join(", ").presence || "(none)"}."
      end

      return if method(call_method).parameters.empty?

      raise ViewComponentSubtemplates::Error,
            "Subtemplate `#{name}` declares locals; standalone rendering requires a subtemplate " \
            "without locals. Pass per-render data through the component's constructor instead."
    end

    def available_subtemplates
      methods.grep(/\Acall_(.+)\z/) { Regexp.last_match(1) }
    end
  end
end

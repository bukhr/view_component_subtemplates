# frozen_string_literal: true

require "erb"
require "active_support/core_ext/erb/util"

module ViewComponentSubtemplates
  class ERB < ::ERB
    def set_eoutvar(compiler, eoutvar = "_erbout")
      super
      compiler.insert_cmd = "#{eoutvar}.<< ::ERB::Util.html_escape"
    end
  end
end

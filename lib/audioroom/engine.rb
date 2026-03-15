# frozen_string_literal: true

module Audioroom
  class Engine < ::Rails::Engine
    isolate_namespace Audioroom
    engine_name PLUGIN_NAME
  end
end

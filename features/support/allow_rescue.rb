ActionController::Base.class_eval do
  cattr_accessor :allow_rescue
end

class ActionDispatch::ShowExceptions
  alias __cucumber_orig_call__ call

  def call(env)
    env['action_dispatch.show_exceptions'] = !!ActionController::Base.allow_rescue
    __cucumber_orig_call__(env)
  end
end


Spinach.hooks.on_tag('allow-rescue') do
  @__orig_allow_rescue = ActionController::Base.allow_rescue
  ActionController::Base.allow_rescue = true
end

Spinach.hooks.after_scenario do
  ActionController::Base.allow_rescue = @__orig_allow_rescue unless @__orig_allow_rescue.nil?
end


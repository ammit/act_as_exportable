require 'rubygems'
require 'active_support'
require "act_as_exportable/version"

ActiveSupport.on_load :active_record do
  require "act_as_exportable/models/active_record_model_extension"
end

# ActiveSupport.on_load :action_controller do
#   # require "postgres-copy/csv_responder"
# end
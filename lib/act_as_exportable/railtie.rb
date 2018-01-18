module ActAsExportable
  class Railtie < Rails::Railtie
    initializer 'act_as_exportable' do |app|
      # ActiveSupport::on_load(:action_view) do
      #   include Sortable::ActionViewExtension
      # end

      ActiveSupport::on_load(:active_record) do
        include ActAsExportable::ActiveRecordModelExtension
      end
    end
  end
end
require 'datatables_crud/version'

require 'rails/all'

def current_path
  File.dirname(__FILE__)
end

# load localizations
Dir.glob(File.join(current_path, 'datatables_crud', 'config', 'locales', '**/*.yml')).each do |locale_file|
  I18n.load_path << locale_file
end

module DatatablesCRUD
  class Railtie < ::Rails::Railtie
    configure do
      ActiveSupport::Dependencies.autoload_paths << "#{__dir__}/datatables_crud/controllers"
      ActiveSupport::Dependencies.autoload_paths << "#{__dir__}/datatables_crud/datatables"
      ActiveSupport::Dependencies.autoload_paths << "#{__dir__}/datatables_crud/support"
    end
  end
end

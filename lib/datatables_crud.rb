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
      %w(controllers datatables support).each do |d|
        ActiveSupport::Dependencies.autoload_paths << "#{__dir__}/datatables_crud/#{d}"
      end
    end
  end
end

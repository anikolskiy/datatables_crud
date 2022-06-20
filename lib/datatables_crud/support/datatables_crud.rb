module DatatablesCRUD
  module Controller
    def crud_actions(*actions)
      actions = [:index, :show, :new, :create, :edit, :update, :destroy] if actions.present? and actions.first == :all

      define_method(:load_resource) do
        object_name = self.class.name.sub('Controller', '').gsub(/.*:/, '').underscore.singularize

        begin
          if params[:action].to_s == 'new'
            object_name = controller_name.singularize
            object = object_name.classify.constantize.new

            if parent_objects.present?
              parent_object_id_field_name = "#{parent_objects.last.name.singularize.underscore}_id"
              object.send "#{parent_object_id_field_name}=", params[parent_object_id_field_name]
            end
          else
            object = object_name.classify.constantize.find(params[:id])
          end

          instance_variable_set("@#{object_name}", object)
        rescue
          redirect_to return_path, flash: { error: t("#{object_name}.notifications.does_not_exist") }
        end
      end

      before_action :load_resource, :only => [:show, :new, :edit, :update, :destroy].select { |action| actions.include?(action) }

      define_method(:load_parent_objects) do
        object_name = controller_name.singularize.to_sym

        parent_objects.each do |clazz|
          obj_name = clazz.name.underscore
          obj_id = params[object_name].try(:[], "#{obj_name}_id") || params["#{obj_name}_id"]
          instance_variable_set("@#{obj_name}", clazz.find(obj_id))
        end
      end

      define_method(:authorize_parent_object) do |operation|
        if parent_objects.present?
          authorize! operation, instance_variable_get("@#{parent_objects.last.name.underscore}")
        end
      end

      before_action :load_parent_objects

      actions.each { |action| send("define_#{action}") }

      if actions.present?
        prepend_view_path(File.dirname(__FILE__) + '/../views')
      end

      @@parent_objects ||= {}
      define_method(:parent_objects) do
        classes = @@parent_objects[namespaced_controller_name] || []

        classes.map do |clazz|
          clazz = [clazz] unless clazz.is_a? Array
          clazz.find { |cl| params["#{cl.name.underscore}_id"] }
        end.compact
      end

      define_method(:singular_path) do
        ([namespace] + parent_objects.map { |po| po.name.underscore } + [controller_name.singularize]).compact.join('_')
      end

      define_method(:index_path) do
        send "#{(([namespace] + parent_objects.map { |po| po.name.underscore } + [controller_name]).compact).join('_')}_path", *parent_objects.map { |obj| params["#{obj.name.underscore}_id"] }
      end

      define_method(:show_path) do |object = nil|
        send "#{(([namespace] + parent_objects.map { |po| po.name.underscore } + [controller_name.singularize]).compact).join('_')}_path", *parent_objects.map { |obj| params["#{obj.name.underscore}_id"] }, object.try(:id) || params[:id]
      end

      define_method(:edit_path) do |object|
        send "edit_#{(([namespace] + parent_objects.map { |po| po.name.underscore } + [controller_name.singularize]).compact).join('_')}_path", *parent_objects.map { |obj| params["#{obj.name.underscore}_id"] }, object.id
      end

      @@return_path ||= {}
      define_method(:return_path) do
        if @@return_path[namespaced_controller_name]
          send(@@return_path[namespaced_controller_name][:path], *@@return_path[namespaced_controller_name][:objects].map { |obj| params["#{obj.name.underscore}_id"] })
        else
          index_path
        end
      end

      define_method(:namespace) do
        self.class.namespace
      end

      define_method(:namespaced_controller_name) do
        self.class.namespaced_controller_name
      end

      helper_method :parent_objects
      helper_method :singular_path
      helper_method :index_path
      helper_method :show_path
      helper_method :edit_path
      helper_method :return_path
      helper_method :namespace
      helper_method :namespaced_controller_name
    end

    def namespace
      self.module_parent.name.underscore unless self.module_parent == Object
    end

    def namespaced_controller_name
      [namespace, controller_name].compact.join('::')
    end

    def parent_objects(*objects)
      @@parent_objects[namespaced_controller_name] = objects
    end

    def return_path(path, *objects)
      @@return_path[namespaced_controller_name] = { :path => path, :objects => objects}
    end

    def define_index
      define_method(:index) do
        @model_class = controller_name.singularize.classify.constantize
        authorize_parent_object :read
        authorize! :read, @model_class

        respond_to do |format|
          format.html
          format.json do
            options = if parent_objects.present?
              parent_object_id_param = "#{parent_objects.last.name.singularize.underscore}_id"
              { :conditions => { parent_object_id_param => params[parent_object_id_param] } }
            else
              {}
            end

            @datatable = self.class.name.sub('Controller', 'Datatable').constantize.new(view_context, options)
            render :json => @datatable
          end
        end
      end
    end

    def define_show
      define_method(:show) do
        authorize! :read, instance_variable_get("@#{controller_name.singularize}")
      end
    end

    def define_new
      define_method(:new) do
        authorize_parent_object :update
        authorize! :create, controller_name.gsub(/^.*\//, '').singularize.classify.constantize
      end
    end

    def define_create
      define_method(:create) do
        authorize_parent_object :update
        authorize! :create, controller_name.singularize.classify.constantize

        object_name = controller_name.singularize
        object = object_name.classify.constantize.new(permitted_params)
        instance_variable_set "@#{object_name}", object

        if object.save
          redirect_to return_path, :notice => t("#{object_name}.notifications.created", :default => t('common.notifications.created'))
        else
          render :new
        end
      end
    end

    def define_edit
      define_method(:edit) do
        object_name = controller_name.singularize
        object = instance_variable_get("@#{object_name}")
        authorize! :update, object
      end
    end

    def define_update
      define_method(:update) do
        object_name = controller_name.singularize
        object = instance_variable_get("@#{object_name}")

        authorize! :update, object

        if object.update_attributes permitted_params
          redirect_to return_path, :notice => t("#{object_name}.notifications.updated", :default => t('common.notifications.updated'))
        else
          render :edit
        end
      end
    end

    def define_destroy
      define_method(:destroy) do
        object_name = controller_name.singularize
        object = instance_variable_get("@#{object_name}")
        authorize! :destroy, object

        if object.destroy
          flash[:notice] = t("#{object_name}.notifications.destroyed", :default => t('common.notifications.destroyed'))
        else
          flash[:error] = t("#{object_name}.notifications.could_not_destroy", :default => t('common.notifications.could_not_destroy'))
        end

        redirect_to return_path
      end
    end
  end
end

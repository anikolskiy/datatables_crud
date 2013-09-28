module DatatablesCRUD
  module Controller
    def crud_actions(*actions)
      actions = [:index, :show, :new, :create, :edit, :update, :destroy] if actions.present? and actions.first == :all
      before_filter :load_resource, :only => [:show, :edit, :update, :destroy].select { |action| actions.include?(action) }

      define_method(:load_parent_objects) do
        parent_objects.each do |clazz|
          obj_name = clazz.name.downcase
          instance_variable_set("@#{obj_name}", clazz.find(params["#{obj_name}_id"]))
        end
      end

      before_filter :load_parent_objects

      actions.each { |action| send("define_#{action}") }

      if actions.present?
        prepend_view_path(File.dirname(__FILE__) + "/../views")
      end

      @@parent_objects ||= {}
      define_method(:parent_objects) do
        @@parent_objects[controller_name] || []
      end

      define_method(:singular_path) do
        (parent_objects.map { |po| po.name.downcase } + [controller_name.singularize]).join('_')
      end

      define_method(:index_path) do
        send "#{(parent_objects.map { |po| po.name.downcase } + [controller_name]).join('_')}_path", *parent_objects.map { |obj| params["#{obj.name.downcase}_id"] }
      end

      define_method(:show_path) do |object = nil|
        send "#{(parent_objects.map { |po| po.name.downcase } + [controller_name.singularize]).join('_')}_path", *parent_objects.map { |obj| params["#{obj.name.downcase}_id"] }, object.try(:id) || params[:id]
      end

      define_method(:edit_path) do |object|
        send "edit_#{(parent_objects.map { |po| po.name.downcase } + [controller_name.singularize]).join('_')}_path", *parent_objects.map { |obj| params["#{obj.name.downcase}_id"] }, object.id
      end

      @@return_path ||= {}
      define_method(:return_path) do
        if @@return_path[controller_name]
          send(@@return_path[controller_name][:path], *@@return_path[controller_name][:objects].map { |obj| params["#{obj.name.downcase}_id"] })
        else
          index_path
        end
      end

      helper_method :parent_objects
      helper_method :singular_path
      helper_method :index_path
      helper_method :show_path
      helper_method :edit_path
      helper_method :return_path
    end

    def parent_objects(*objects)
      @@parent_objects[controller_name] = objects
    end

    def return_path(path, *objects)
      @@return_path[controller_name] = { :path => path, :objects => objects}
    end

    def define_index
      define_method(:index) do
        @model_class = controller_name.singularize.classify.constantize
        unauthorized! if cannot? :read, @model_class

        respond_to do |format|
          format.html
          format.json do
            @datatable = self.class.name.sub('Controller', 'Datatable').constantize.new(view_context)
            render :json => @datatable
          end
        end
      end
    end

    def define_show
    end

    def define_new
      define_method(:new) do
        unauthorized! if cannot? :create, controller_name.singularize.classify.constantize

        object_name = controller_name.singularize
        object = object_name.classify.constantize.new
        parent_object_id_field_name = "#{parent_objects.last.name.singularize.downcase}_id"
        object.send "#{parent_object_id_field_name}=", params[parent_object_id_field_name]
        instance_variable_set("@#{object_name}", object)
      end
    end

    def define_create
      define_method(:create) do
        unauthorized! if cannot? :create, controller_name.singularize.classify.constantize

        object_name = controller_name.singularize
        object = object_name.classify.constantize.new(params[object_name.to_sym])
        instance_variable_set "@#{object_name}", object

        if object.save
          redirect_to return_path, :notice => t("#{object_name}.notifications.created")
        else
          render :new
        end
      end
    end

    def define_edit
    end

    def define_update
      define_method(:update) do
        object_name = controller_name.singularize
        object = instance_variable_get("@#{object_name}")

        unauthorized! if cannot? :update, object

        if object.update_attributes params[object_name.to_sym]
          redirect_to return_path, :notice => t("#{object_name}.notifications.updated")
        else
          render :edit
        end
      end
    end

    def define_destroy
      define_method(:destroy) do
        object_name = controller_name.singularize
        object = instance_variable_get("@#{object_name}")
        unauthorized! if cannot? :destroy, object

        if object.destroy
          flash[:notice] = t("#{object_name}.notifications.destroyed")
        else
          flash[:error] = t("#{object_name}.notifications.could_not_destroy")
        end

        redirect_to return_path
      end
    end
  end
end
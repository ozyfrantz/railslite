class Route
    attr_reader :pattern, :http_method, :controller_class, :action_name

    def initialize(pattern, http_method, controller_class, action_name)
      @pattern = pattern
      @http_method = http_method
      @controller_class = controller_class
      @action_name = action_name
    end

    # checks if pattern matches path and method matches request method
    def matches?(req)
      if req.path.match(@pattern).nil?
        matches = false
      else
        matches = true
      end
      req.request_method.downcase.to_sym == @http_method && matches
    end

    # use pattern to pull out route params (save for later?)
    # instantiate controller and call controller action
    def run(req, res)
      match_data = @pattern.match(req.path)
      route_params = match_data.length > 1 ? {"id" => match_data[:id]} : {}
      unless req.body.nil?
        raise unless req.body.include?(@controller_class.form_authenticity_token)
      end
      @controller_class.new(req, res, route_params).invoke_action(@action_name)
    end
  end

  class Router
    attr_reader :routes

    def initialize
      @routes = []
    end

    # simply adds a new route to the list of routes
    def add_route(pattern, method, controller_class, action_name, new_url=nil)
      unless pattern.is_a?(Regexp)
        pattern = /^#{pattern}$/
      end
      @routes << Route.new(pattern, method, controller_class, action_name)
      if controller_class.to_s.slice(/(?<name>.+)Controller/, "name").nil?
        return "This is not controller syntax."
      elsif new_url.nil?
        URLHelper.new(controller_class, action_name).create
      else
        controller_class.add_custom_url(new_url)
      end
    end

    # evaluate the proc in the context of the instance
    # for syntactic sugar :)
    def draw(&proc)
      self.instance_eval(&proc)
    end

    # make each of these methods that
    # when called add route
    [:get, :post, :put, :delete].each do |http_method|
      define_method(http_method.to_s) do |pattern, controller_class, action_name|
        add_route(pattern, http_method, controller_class, action_name)
      end
    end

    # should return the route that matches this request
    def match(req)
      @routes.each do |route|
        return route if route.matches?(req)
      end
      return nil
    end

    # either throw 404 or call run on a matched route
    def run(req, res)
      route = self.match(req)
      if route.nil?
        res.status = 404
      else
        route.run(req, res)
      end
    end

  end
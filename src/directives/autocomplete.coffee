###
@chalk overview
@name Autocomplete

@description
A directive for providing suggestions while typing into the field

@dependencies
- mac-menu

@param {String} ng-model Assignable angular expression to data-bind to
@param {String} mac-placeholder Placeholder text
@param {String} mac-autocomplete-url Url to fetch autocomplete dropdown list data. URL may include GET params e.g. "/users?nocache=1"
@param {Expression} mac-autocomplete-source Local data source
@param {Boolean} mac-autocomplete-disabled Boolean value if autocomplete should be disabled
@param {Function} mac-autocomplete-on-select Function called when user select on an item
       - `selected` - {Object} The item selected
@param {Function} mac-autocomplete-on-success function called on success ajax request
        - `data` - {Object} Data returned from the request
        - `status` - {Number} The status code of the response
        - `header` - {Object} Header of the response
@param {Function} mac-autocomplete-on-error Function called on ajax request error
        - `data` - {Object} Data returned from the request
        - `status` - {Number} The status code of the response
        - `header` - {Object} Header of the response
@param {String}  mac-autocomplete-label The label to display to the users (default "name")
@param {String}  mac-autocomplete-query The query parameter on GET command (default "q")
@param {Integer} mac-autocomplete-delay Delay on fetching autocomplete data after keyup (default 800)
###

angular.module("Mac").directive "macAutocomplete", [
  "$animate"
  "$http"
  "$filter"
  "$compile"
  "$timeout"
  "$parse"
  "$rootScope"
  "keys"
  ($animate, $http, $filter, $compile, $timeout, $parse, $rootScope, keys) ->
    restrict:    "E"
    templateUrl: "template/autocomplete.html"
    replace:     true
    require:     "ngModel"

    link: ($scope, element, attrs, ctrl) ->
      labelKey = attrs.macAutocompleteLabel  or "name"
      queryKey = attrs.macAutocompleteQuery  or "q"
      delay    = +(attrs.macAutocompleteDelay or 800)
      inside   = attrs.macAutocompleteInside?

      autocompleteUrl = $parse attrs.macAutocompleteUrl
      onSelect        = $parse attrs.macAutocompleteOnSelect
      onSuccess       = $parse attrs.macAutocompleteOnSuccess
      onError         = $parse attrs.macAutocompleteOnError
      source          = $parse attrs.macAutocompleteSource
      disabled        = $parse attrs.macAutocompleteDisabled

      currentAutocomplete = []
      timeoutId           = null
      onSelectBool        = false

      $menuScope       = $rootScope.$new(true)
      $menuScope.items = []
      $menuScope.index = 0

      menuEl = angular.element("<mac-menu></mac-menu>")
      menuEl.attr
        "mac-menu-items":  "items"
        "mac-menu-style":  "style"
        "mac-menu-select": "select(index)"
        "mac-menu-index":  "index"
      # Precompile menu element
      $compile(menuEl) $menuScope

      ctrl.$parsers.push (value) ->
        # If value is more than an empty string,
        # autocomplete is enabled and not 'onSelect' cycle
        if value and not disabled($scope) and not onSelectBool
          $timeout.cancel timeoutId if timeoutId?
          if delay > 0
            timeoutId = $timeout ->
              queryData value
            , delay
          else
            queryData value
        else
          reset()

        onSelectBool = false

        return value

      #
      # @function
      # @name appendMenu
      # @description
      # Adding menu to DOM
      #
      appendMenu = ->
        if inside
          element.after menuEl
        else
          angular.element(document.body).append menuEl

      #
      # @function
      # @name reset
      # @description
      # Resetting autocomplete
      #
      reset = ->
        $menuScope.items = []
        $menuScope.index = 0
        menuEl.remove()

      #
      # @function
      # @name positionMenu
      # @description
      # Calculate the style include position and width for menu
      #
      positionMenu = ->
        if $menuScope.items.length > 0
          $menuScope.style       = element.offset()
          $menuScope.style.top  += element.outerHeight()
          $menuScope.style.width = element.outerWidth()

          angular.forEach $menuScope.style, (value, key) ->
            if not isNaN(+value) and angular.isNumber +value
              value = "#{value}px"
            $menuScope.style[key] = value

          appendMenu()

      #
      # @function
      # @name updateItem
      # @description
      # Update list of items getting passed to menu
      # @param {Array} data Array of data
      #
      updateItem = (data = []) ->
        if data.length > 0
          currentAutocomplete = data
          $menuScope.items    = []
          for item in data
            label = value = item[labelKey] or item
            $menuScope.items.push {label, value}

      #
      # @function
      # @name queryData
      # @description
      # Used for querying data
      # @param {String} query Search query
      #
      queryData = (query) ->
        url = autocompleteUrl $scope

        if url
          options =
            method: "GET"
            url:    url
            params: {}
          options.params[queryKey] = query

          $http(options)
            .success (data, status, headers, config) ->
              dataList  = onSuccess $scope, {data, status, headers}
              dataList ?= data.data

              updateItem dataList
              positionMenu()
            .error (data, status, headers, config) ->
              onError $scope, {data, status, headers}
        else
          updateItem $filter("filter")(source($scope), query)
          positionMenu()

      $menuScope.select = (index) ->
        selected = currentAutocomplete[index]
        onSelect $scope, {selected}

        label        = $menuScope.items[index].label or ""
        onSelectBool = true

        if attrs.ngModel?
          ctrl.$setViewValue label
          ctrl.$render()

        reset()

      element.bind "keydown", (event) ->
        switch event.which
          when keys.DOWN
            $scope.$apply ->
              $menuScope.index = ($menuScope.index + 1) % $menuScope.items.length
          when keys.UP
            $scope.$apply ->
              $menuScope.index = (if $menuScope.index then $menuScope.index else $menuScope.items.length) - 1
          when keys.ENTER
            $scope.$apply ->
              if $menuScope.items.length > 0
                $menuScope.select $menuScope.index
          when keys.ESCAPE
            $scope.$apply -> reset()

        return true

      angular.element(document).bind "click", (event) ->
        if $menuScope.items.length > 0
          $scope.$apply -> reset()

      $scope.$on "$destroy", ->
        # Remove menu on body when autocomplete is removed
        menuEl.remove()

      #
      # @event
      # @name reset-mac-autocomplete
      # @description
      # Event to reset autocomplete
      #
      $scope.$on "reset-mac-autocomplete", -> reset()
]

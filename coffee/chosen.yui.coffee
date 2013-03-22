###
Chosen source: generate output using 'cake build'
Copyright (c) 2011 by Harvest
###
#root = this
#Y = YUI.add("chosen", {}, "2.0.0.0", { "requires": ["node", "base-build", "plugin", "event", "event-custom" "event-valuechange", "array-extras", "transition"] });
root = this
YUI.add("chosen", (Y) ->
  class Chosen extends AbstractChosen

    setup: ->
      @form_field_y = Y.Node @form_field
      @current_value = @form_field_y.get("value")
      @is_rtl = @form_field_y.hasClass "chzn-rtl"

    finish_setup: ->
      @form_field_y.addClass "chzn-done"

    set_up_html: ->
      @container_id = if @form_field.id.length then @form_field.id.replace(/[^\w]/g, '_') else this.generate_field_id()
      @container_id += "_chzn"

      container_classes = ["chzn-container"]
      container_classes.push "chzn-container-" + (if @is_multiple then "multi" else "single")
      container_classes.push @form_field.className if @inherit_select_classes && @form_field.className
      container_classes.push "chzn-rtl" if @is_rtl

      @f_width = @form_field_y.get("offsetWidth")

      container_props = 
        id: @container_id
        class: container_classes.join ' '
        width: (@f_width) + 'px' #use parens around @f_width so coffeescript doesn't think + ' px' is a function parameter
        title: @form_field.title

      if @is_multiple
        html = '<ul class="chzn-choices"><li class="search-field"><input type="text" value="' + @default_text + '" class="default" autocomplete="off" style="width:25px;" /></li></ul><div class="chzn-drop" style="left:-9000px;"><ul class="chzn-results"></ul></div>'
      else
        html = '<a href="javascript:void(0)" class="chzn-single chzn-default" tabindex="-1"><span>' + @default_text + '</span><div><b></b></div></a><div class="chzn-drop" style="left:-9000px;"><div class="chzn-search"><input type="text" autocomplete="off" /></div><ul class="chzn-results"></ul></div>'

      container_div = Y.Node.create("<div />")
      @form_field_y.hide().insert(container_div, "after")
      container_content = Y.Node.create(html)
      container_div.insert(container_content, 0);

      container_div.set("id", container_props.id).addClass(container_classes.join ' ').setStyle("width", container_props.width).set("title", container_props.title)

      

      @container = Y.one("#" + @container_id)
      @dropdown = @container.one("div.chzn-drop")

      dd_top = @container.getComputedStyle("height").split("px")[0]
      dd_width = (@f_width - get_side_border_padding(@dropdown))

      @dropdown.setStyles({"width": dd_width  + "px", "top": dd_top + "px"})

      @search_field = @container.one('input')
      @search_results = @container.one('ul.chzn-results')
      this.search_field_scale()

      @search_no_results = @container.one('li.no-results')

      if @is_multiple
        @search_choices = @container.one('ul.chzn-choices')
        @search_container = @container.one('li.search-field')
      else
        @search_container = @container.one('div.chzn-search')
        @selected_item = @container.one('.chzn-single')
        sf_width = dd_width - get_side_border_padding(@search_container) - get_side_border_padding(@search_field)
        @search_field.setStyles( {"width" : sf_width + "px"} )
      #YOU ARE HERE
      this.results_build()
      
      this.set_tab_index()
      this.fire("liszt:ready", {chosen: this})

    register_observers: ->
      container_eventmap =
        mousedown: this.container_mousedown,
        mouseup: this.container_mouseup,
        mouseenter: this.mouse_enter,
        mouseleave: this.mouse_leave
      
      container_events = @container.on container_eventmap, null, this

      search_results_eventmap =
        mouseup: this.search_results_mouseup,
        mouseover: this.search_results_mouseover,
        mouseout: this.search_results_mouseout

      @search_results.on search_results_eventmap, null, this

      form_field_y_eventmap = {
        "liszt:updated": this.results_update_field
        "liszt:activate": this.activate_field
        "liszt:open": this.container_mousedown
      }

      this.on(form_field_y_eventmap, null, this);

      search_field_eventmap =
        blur: this.input_blur,
        keyup: this.keyup_checker,
        keydown: this.keydown_checker,
        focus: this.input_focus

      @search_field.on search_field_eventmap, null, this

      if @is_multiple
        @search_choices.on "click", this.choices_click, this
        # @search_choices.click (evt) => this.choices_click(evt); return
      else
        @container.on "click", (e) =>
          e.preventDefault()

    search_field_disabled: ->
      @is_disabled = @form_field_y.get("disabled")
      if(@is_disabled)
        @container.addClass 'chzn-disabled'
        @search_field.set("disabled", true)
        @selected_item.detach "focus", @activate_action if !@is_multiple
        this.close_field()
      else
        @container.removeClass 'chzn-disabled'
        @search_field.set("disabled", false)
        @selected_item.on "focus", @activate_action, this if !@is_multiple

    container_mousedown: (evt) ->
      if !@is_disabled
        target_closelink =  if evt? then (evt.target).hasClass "search-choice-close" else false
        if evt and evt.type is "mousedown" and not @results_showing
          evt.preventDefault()
        if not @pending_destroy_click and not target_closelink
          if not @active_field
            @search_field.set("value", "") if @is_multiple
            Y.one("document").on "click", @click_test_action, this
            this.results_show()
          else if not @is_multiple and evt and ((evt.target is @selected_item) || evt.target.ancestors("a.chzn-single").size())
            evt.preventDefault()
            this.results_toggle()

          this.activate_field()
        else
          @pending_destroy_click = false

    container_mouseup: (evt) ->
      this.results_reset(evt) if evt.target.getDOMNode().nodeName is "ABBR" and not @is_disabled

    blur_test: (evt) ->
      this.close_field() if not @active_field and @container.hasClass "chzn-container-active"

    close_field: ->
      Y.one("document").detach "click", @click_test_action, this

      @active_field = false
      this.results_hide()

      @container.removeClass "chzn-container-active"
      this.winnow_results_clear()
      this.clear_backstroke()

      this.show_search_field_default()
      this.search_field_scale()
      false

    activate_field: ->
      @container.addClass "chzn-container-active"
      @active_field = true

      @search_field.set("value", @search_field.get("value"))
      @search_field.focus()


    test_active_click: (evt) ->
      if not Y.Lang.isUndefined(evt.currentTarget.ancestor("#" +  @container_id))
        @active_field = true
      else
        this.close_field()

    results_build: ->
      @parsing = true
      @results_data = root.SelectParser.select_to_array @form_field

      if @is_multiple and @choices > 0
        @search_choices.one("li.search-choice").remove()
        @choices = 0
      else if not @is_multiple
        @selected_item.addClass("chzn-default").one("span").set("text", @default_text)

        if @disable_search or @form_field.options.length <= @disable_search_threshold
          @container.addClass "chzn-container-single-nosearch"
        else
          @container.removeClass "chzn-container-single-nosearch"

      content = ''
      for data in @results_data
        if data.group
          content += this.result_add_group data
        else if !data.empty
          content += this.result_add_option data
          if data.selected and @is_multiple
            this.choice_build data
          else if data.selected and not @is_multiple
            @selected_item.removeClass("chzn-default").one("span").set("text", data.text)

            this.single_deselect_control_build() if @allow_single_deselect

      this.search_field_disabled()
      this.show_search_field_default()
      this.search_field_scale()
      @search_results.setHTML(content)
      @parsing = false

    result_add_group: (group) ->
      if not group.disabled
        group.dom_id = @container_id + "_g_" + group.array_index
        '<li id="' + group.dom_id + '" class="group-result">' + Y.Node.create("<div />").set("text", group.label).getHTML() + '</li>'
      else
        ""

    result_do_highlight: (el) ->
      if el
        this.result_clear_highlight()

        @result_highlight = el
        @result_highlight.addClass "highlighted"

        # @result_highlight.scrollIntoView()
        maxHeight = parseInt @search_results.getStyle("maxHeight"), 10
        visible_top = @search_results.get "scrollTop"
        visible_bottom = maxHeight + visible_top

        high_top = (@result_highlight.getY() - @search_results.getY()) + @search_results.get "scrollTop"
        high_bottom = high_top + @result_highlight.get "offsetHeight"

        if high_bottom >= visible_bottom
          @search_results.set "scrollTop", if (high_bottom - maxHeight) > 0 then (high_bottom - maxHeight) else 0
        else if high_top < visible_top
          @search_results.set "scrollTop", high_top

    result_clear_highlight: ->
      @result_highlight.removeClass "highlighted" if @result_highlight
      @result_highlight = null

    results_show: ->
      if not @is_multiple
        @selected_item.addClass "chzn-single-with-drop"
        if @result_single_selected
          this.result_do_highlight( @result_single_selected )
      else if @max_selected_options <= @choices
        @form_field_y.fire("liszt:maxselected", {chosen: this})
        return false

      dd_top = if @is_multiple then @container.getComputedStyle("height").split("px")[0] else (@container.getComputedStyle("height").split("px")[0] - 1)
      @form_field_y.fire("liszt:showing_dropdown", {chosen: this})
      @dropdown.setStyles {"top":  dd_top + "px", "left":0}
      @results_showing = true

      @search_field.focus()
      @search_field.set "value", @search_field.get "value"

      this.winnow_results()

    results_hide: ->
      @selected_item.removeClass "chzn-single-with-drop" unless @is_multiple
      this.result_clear_highlight()
      @form_field_y.fire("liszt:hiding_dropdown", {chosen: this})
      @dropdown.setStyles {"left":"-9000px"}
      @results_showing = false


    set_tab_index: (el) ->
      if @form_field_y.hasAttribute "tabindex"
        ti = @form_field_y.getAttribute "tabindex"
        @form_field_y.setAttribute "tabindex", -1
        @search_field.setAttribute "tabindex", ti

    show_search_field_default: ->
      if @is_multiple and @choices < 1 and not @active_field
        @search_field.set "value", @default_text
        @search_field.addClass "default"
      else
        @search_field.set "value", ""
        @search_field.removeClass "default"

    search_results_mouseup: (evt) ->
      target = if evt.target.hasClass "active-result" then evt.target else evt.target.ancestor(".active-result")
      if target
        @result_highlight = target
        this.result_select(evt)
        @search_field.focus()

    search_results_mouseover: (evt) ->
      target = if evt.target.hasClass "active-result" then evt.target else evt.target.ancestor(".active-result")
      this.result_do_highlight( target ) if target?

    search_results_mouseout: (evt) ->
      this.result_clear_highlight() if evt.target.hasClass "active-result" or evt.target.ancestor(".active-result")


    choices_click: (evt) ->
      evt.preventDefault()
      if( @active_field and not(evt.target.hasClass "search-choice" or evt.target.ancestor(".search-choice")) and not @results_showing )
        this.results_show()

    choice_build: (item) ->
      if @is_multiple and @max_selected_options <= @choices
        @form_field_y.fire("liszt:maxselected", {chosen: this})
        return false # fire event
      choice_id = @container_id + "_c_" + item.array_index
      @choices += 1
      if item.disabled
        html = '<li class="search-choice search-choice-disabled" id="' + choice_id + '"><span>' + item.html + '</span></li>'
      else
        html = '<li class="search-choice" id="' + choice_id + '"><span>' + item.html + '</span><a href="javascript:void(0)" class="search-choice-close" rel="' + item.array_index + '"></a></li>'
      @search_container.insert html, "before"
      # link = $('#' + choice_id).find("a").first()
      link = Y.one("#" + choice_id + " a")
      link.on "click", ((evt) -> this.choice_destroy_link_click(evt)), this if link?

    choice_destroy_link_click: (evt) ->
      evt.preventDefault()
      if not @is_disabled
        @pending_destroy_click = true
        this.choice_destroy evt.currentTarget
      else
        evt.stopPropagation

    choice_destroy: (link) ->
      if link? and this.result_deselect (link.getAttribute "rel")
        @choices -= 1
        this.show_search_field_default()

        this.results_hide() if @is_multiple and @choices > 0 and @search_field.get("value").length < 1

        link.ancestor("li").remove()

        this.search_field_scale()

    results_reset: ->
      @form_field.options[0].selected = true
      @selected_item.one("span")?.text @default_text
      @selected_item.addClass("chzn-default") if not @is_multiple
      this.show_search_field_default()
      this.results_reset_cleanup()
      @form_field_y.simulate "change"
      this.results_hide() if @active_field

    results_reset_cleanup: ->
      @current_value = @form_field_y.get("value")
      @selected_item.one("abbr")?.remove()

    result_select: (evt) ->
      if @result_highlight
        high = @result_highlight
        high_id = high.get "id"

        this.result_clear_highlight()

        if @is_multiple
          this.result_deactivate high
        else
          result_selected = @search_results.one(".result-selected")
          result_selected.removeClass("result-selected") if result_selected

          @result_single_selected = high
          @selected_item.removeClass "chzn-default"

        high.addClass "result-selected"

        position = high_id.substr(high_id.lastIndexOf("_") + 1 )
        item = @results_data[position]
        item.selected = true

        @form_field.options[item.options_index].selected = true

        if @is_multiple
          this.choice_build item
        else
          span = @selected_item.one("span")
          span.set("text", item.text) if span

          this.single_deselect_control_build() if @allow_single_deselect

        this.results_hide() unless (evt.metaKey or evt.ctrlKey) and @is_multiple

        @search_field.set "value", ""

        @form_field_y.simulate "change", {'selected': @form_field.options[item.options_index].value} if @is_multiple || @form_field_y.get("value") != @current_value
        @current_value = @form_field_y.get("value")
        this.search_field_scale()

    result_activate: (el) ->
      el.addClass("active-result")

    result_deactivate: (el) ->
      el.removeClass("active-result")

    result_deselect: (pos) ->
      result_data = @results_data[pos]

      if not @form_field.options[result_data.options_index].disabled
        result_data.selected = false

        @form_field.options[result_data.options_index].selected = false
        result = Y.one("#" + @container_id + "_o_" + pos)
        result.removeClass("result-selected").addClass("active-result").show()

        this.result_clear_highlight()
        this.winnow_results()

        @form_field_y.simulate "change", {deselected: @form_field.options[result_data.options_index].value}
        this.search_field_scale()

        return true
      else
        return false

    single_deselect_control_build: ->
      @selected_item.find("span").first().after "<abbr class=\"search-choice-close\"></abbr>" if @allow_single_deselect and @selected_item.find("abbr").length < 1

    winnow_results: ->
      this.no_results_clear()

      results = 0

      searchText = if @search_field.get("value") is @default_text then "" else Y.Escape.html(Y.Lang.trim(@search_field.get("value")))
      regexAnchor = if @search_contains then "" else "^"
      regex = new RegExp(regexAnchor + searchText.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&"), 'i')
      zregex = new RegExp(searchText.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&"), 'i')

      for option in @results_data
        if not option.disabled and not option.empty
          if option.group
            Y.one("#" + option.dom_id).setStyle("display", "none") if Y.one("#" + option.dom_id)?
            #$('#' + option.dom_id).setStyles('display', 'none')
          else if not (@is_multiple and option.selected)
            found = false
            result_id = option.dom_id
            result = Y.one("#" + result_id)

            if regex.test option.html
              found = true
              results += 1
            else if @enable_split_word_search and (option.html.indexOf(" ") >= 0 or option.html.indexOf("[") == 0)
              #TODO: replace this substitution of /\[\]/ with a list of characters to skip.
              parts = option.html.replace(/\[|\]/g, "").split(" ")
              if parts.length
                for part in parts
                  if regex.test part
                    found = true
                    results += 1

            if found
              if searchText.length
                startpos = option.html.search zregex
                text = option.html.substr(0, startpos + searchText.length) + '</em>' + option.html.substr(startpos + searchText.length)
                text = text.substr(0, startpos) + '<em>' + text.substr(startpos)
              else
                text = option.html

              result.setHTML(text)
              this.result_activate result

              resultNode = Y.one("#" + @results_data[option.group_array_index].dom_id) if option.group_array_index?
              resultNode.setStyle('display', 'list-item') if resultNode?
            else
              this.result_clear_highlight() if @result_highlight and result_id is @result_highlight.get "id"
              this.result_deactivate result

      if results < 1 and searchText.length
        this.no_results searchText
      else
        this.winnow_results_set_highlight()

    winnow_results_clear: ->
      @search_field.set "value", ""
      lis = @search_results.all("li")

      lis.each (li) =>
        if li.hasClass "group-result"
          li.setStyle('display', 'auto')
        else if not @is_multiple or not li.hasClass "result-selected"
          this.result_activate li

    winnow_results_set_highlight: ->
      if not @result_highlight

        selected_results = if not @is_multiple then @search_results.all(".result-selected.active-result") else new Y.NodeList()
        do_high = if selected_results.size() then selected_results.item(0) else @search_results.one(".active-result")

        this.result_do_highlight do_high if do_high?

    no_results: (terms) ->
      no_results_html = Y.Node.create('<li class="no-results">' + @results_none_found + ' "<span></span>"</li>')
      no_results_html.one("span")?.setHTML(terms)

      @search_results.appendChild no_results_html

    no_results_clear: ->
      no_results = @search_results.one(".no-results")
      no_results.remove() if no_results

    keydown_arrow: ->
      if not @result_highlight
        first_active = @search_results.one("li.active-result")
        this.result_do_highlight first_active if first_active
      else if @results_showing
        next_sib = @result_highlight.next("li.active-result")
        this.result_do_highlight next_sib if next_sib
      this.results_show() if not @results_showing

    keyup_arrow: ->
      if not @results_showing and not @is_multiple
        this.results_show()
      else if @result_highlight
        prev_sibs = @result_highlight.previous("li.active-result")

        if prev_sibs
          this.result_do_highlight prev_sibs
        else
          this.results_hide() if @choices > 0
          this.result_clear_highlight()

    keydown_backstroke: ->
      if @pending_backstroke
        this.choice_destroy @pending_backstroke.one("a")
        this.clear_backstroke()
      else
        next_available_destroy = @search_container.siblings("li.search-choice").pop()
        if next_available_destroy and not next_available_destroy.hasClass("search-choice-disabled")
          @pending_backstroke = next_available_destroy
          if @single_backstroke_delete
            @keydown_backstroke()
          else
            @pending_backstroke.addClass "search-choice-focus"

    clear_backstroke: ->
      @pending_backstroke.removeClass "search-choice-focus" if @pending_backstroke
      @pending_backstroke = null

    keydown_checker: (evt) ->
      stroke = evt.which ? evt.keyCode
      this.search_field_scale()

      this.clear_backstroke() if stroke != 8 and this.pending_backstroke

      switch stroke
        when 8
          @backstroke_length = this.search_field.get("value").length
          break
        when 9
          this.result_select(evt) if this.results_showing and not @is_multiple
          @mouse_on_container = false
          break
        when 13
          evt.preventDefault()
          break
        when 38
          evt.preventDefault()
          this.keyup_arrow()
          break
        when 40
          this.keydown_arrow()
          break

    search_field_scale: ->
      if @is_multiple
        h = 0
        w = 0

        style_block =
          position :"absolute",
          left: "-1000px",
          top: "-1000px",
          display:"block"

        styles = ['font-size','font-style', 'font-weight', 'font-family','line-height', 'text-transform', 'letter-spacing']

        for style in styles
          style_block[style] = @search_field.getStyle(style)

        div = Y.Node.create("<div />")
        div.setStyles(style_block)
        div.set("text", @search_field.get("value"))
        Y.one("body").append(div)

        w = parseInt(div.getComputedStyle("width").split("px")[0], 10) + 25
        div.remove()

        if( w > @f_width-10 )
          w = @f_width - 10

        @search_field.setStyle("width", w + "px")

        dd_top = parseInt(@container.getComputedStyle("height").split("px")[0])
        @dropdown.setStyles({"top":  dd_top + "px"})

    generate_random_id: ->
      string = "sel" + this.generate_random_char() + this.generate_random_char() + this.generate_random_char()
      while $("#" + string).length > 0
        string += this.generate_random_char()
      string


  Y.augment(Chosen, Y.EventTarget)
  root.Chosen = Chosen

  Y.Chosen = Y.Base.create("chosen", Y.Plugin.Base, [], {
    initializer: (options) ->
      ieUA = Y.UA.ie

      # Do no harm and return as soon as possible for unsupported browsers, namely IE6 and IE7
      # Continue on if running IE document type but in compatibility mode
      return this if ieUA is 6 or (ieUA is 7 and document.documentMode is 7)

      attach_chosen_instance = (node) =>
        if not input.hasClass("chzn-done")
          #Chosen is expecting a DOM Node not a YUI Node
          chosen_instance = new Chosen(input.getDOMNode(), options)
          input.setData("chosen", chosen_instance)
          Y.mix(this, chosen_instance, true)

      if this.get("host").test("form")
        this.get("host").all("select").each((input) ->
            input.plug(Y.Chosen)
        )
      else
        input = this.get("host")
        attach_chosen_instance input
  }, {
      NS: "chosen",
      NAME: "Chosen"
  });

  get_side_border_padding = (elmt) ->
    side_border_padding = elmt.get("offsetWidth") - elmt.getComputedStyle("width").split("px")[0]

  root.get_side_border_padding = get_side_border_padding

,"2.0.0.0", { "requires": ["node", "base-build", "plugin", "event", "event-custom", "event-valuechange", "node-event-simulate", "array-extras", "transition", "escape"] })

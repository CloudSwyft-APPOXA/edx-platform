if Backbone?
  class @DiscussionThreadListView extends Backbone.View
    events:
      "click .search": "showSearch"
      "click .browse": "toggleTopicDrop"
      "keydown .post-search-field": "performSearch"
      "click .sort-bar a": "sortThreads"
      "click .browse-topic-drop-menu": "filterTopic"
      "click .browse-topic-drop-search-input": "ignoreClick"
      "click .post-list .list-item a": "threadSelected"
      "click .post-list .more-pages a": "loadMorePages"

    initialize: ->
      @displayedCollection = new Discussion(@collection.models, pages: @collection.pages)
      @collection.on "change", @reloadDisplayedCollection
      @sortBy = "date"
      @discussionIds=""
      @collection.on "reset", (discussion) =>
        board = $(".current-board").html()
        @displayedCollection.current_page = discussion.current_page
        @displayedCollection.pages = discussion.pages
        @displayedCollection.reset discussion.models
        # TODO: filter correctly
        # target = _.filter($("a.topic:contains('#{board}')"), (el) -> el.innerText == "General" || el.innerHTML == "General")
        # if target.length > 0
        #   @filterTopic($.Event("filter", {'target': target[0]}))
      @collection.on "add", @addAndSelectThread
      @sidebar_padding = 10
      @sidebar_header_height = 87
      @boardName
      @template = _.template($("#thread-list-template").html())
      @current_search = ""

    reloadDisplayedCollection: (thread) =>
      thread_id = thread.get('id')
      content = @renderThread(thread)
      current_el = @$("a[data-id=#{thread_id}]")
      active = current_el.hasClass("active")
      current_el.replaceWith(content)
      if active
        @setActiveThread(thread_id)

    #TODO fix this entire chain of events
    addAndSelectThread: (thread) =>
      commentable_id = thread.get("commentable_id")
      commentable = @$(".board-name[data-discussion_id]").filter(-> $(this).data("discussion_id").id == commentable_id)
      @setTopicHack(commentable)
      @retrieveDiscussion commentable_id, =>
        @trigger "thread:created", thread.get('id')

    updateSidebar: =>

      scrollTop = $(window).scrollTop();
      windowHeight = $(window).height();

      discussionBody = $(".discussion-article")
      discussionsBodyTop = if discussionBody[0] then discussionBody.offset().top
      discussionsBodyBottom = discussionsBodyTop + discussionBody.outerHeight()

      sidebar = $(".sidebar")
      if scrollTop > discussionsBodyTop - @sidebar_padding
        sidebar.addClass('fixed');
        sidebar.css('top', @sidebar_padding);
      else
        sidebar.removeClass('fixed');
        sidebar.css('top', '0');

      sidebarWidth = .31 * $(".discussion-body").width();
      sidebar.css('width', sidebarWidth + 'px');

      sidebarHeight = windowHeight - Math.max(discussionsBodyTop - scrollTop, @sidebar_padding)

      topOffset = scrollTop + windowHeight
      discussionBottomOffset = discussionsBodyBottom + @sidebar_padding
      amount = Math.max(topOffset - discussionBottomOffset, 0)

      sidebarHeight = sidebarHeight - @sidebar_padding - amount
      sidebarHeight = Math.min(sidebarHeight + 1, discussionBody.outerHeight())
      sidebar.css 'height', sidebarHeight

      postListWrapper = @$('.post-list-wrapper')
      postListWrapper.css('height', (sidebarHeight - @sidebar_header_height - 4) + 'px')


    # Because we want the behavior that when the body is clicked the menu is
    # closed, we need to ignore clicks in the search field and stop propagation.
    # Without this, clicking the search field would also close the menu.
    ignoreClick: (event) ->
        event.stopPropagation()

    render: ->
      @timer = 0
      @$el.html(@template())

      $(window).bind "scroll", @updateSidebar
      $(window).bind "resize", @updateSidebar

      @displayedCollection.on "reset", @renderThreads
      @displayedCollection.on "thread:remove", @renderThreads
      @renderThreads()
      @

    renderThreads: =>
      @$(".post-list").html("")
      rendered = $("<div></div>")
      for thread in @displayedCollection.models
        content = @renderThread(thread)
        rendered.append content
        content.wrap("<li class='list-item' data-id='\"#{thread.get('id')}\"' />")

      @$(".post-list").html(rendered.html())
      @renderMorePages()
      @updateSidebar()
      @trigger "threads:rendered"

    renderMorePages: ->
      if @displayedCollection.hasMorePages()
        @$(".post-list").append("<li class='more-pages'><a href='#'>Load more</a></li>")

    loadMorePages: (event) ->
      event.preventDefault()
      @$(".more-pages").html('<div class="loading-animation"></div>')
      @$(".more-pages").addClass("loading")
      @collection.retrieveAnotherPage(@current_search, @discussionIds, @sortBy)

    renderThread: (thread) =>
      content = $(_.template($("#thread-list-item-template").html())(thread.toJSON()))
      if thread.get('subscribed')
        content.addClass("followed")
      if thread.get('endorsed')
        content.addClass("resolved")
      if thread.get('viewed')
        content.addClass("viewed")
      @highlight(content)


    highlight: (el) ->
      el.html(el.html().replace(/&lt;mark&gt;/g, "<mark>").replace(/&lt;\/mark&gt;/g, "</mark>"))

    renderThreadListItem: (thread) =>
      view = new ThreadListItemView(model: thread)
      view.on "thread:selected", @threadSelected
      view.on "thread:removed", @threadRemoved
      view.render()
      @$(".post-list").append(view.el)

    threadSelected: (e) =>
      thread_id = $(e.target).closest("a").data("id")
      @setActiveThread(thread_id)
      @trigger("thread:selected", thread_id)
      false

    threadRemoved: (thread_id) =>
      @trigger("thread:removed", thread_id)

    setActiveThread: (thread_id) ->
      @$(".post-list a[data-id!='#{thread_id}']").removeClass("active")
      @$(".post-list a[data-id='#{thread_id}']").addClass("active")

    showSearch: ->
      @$(".browse").removeClass('is-dropped')
      @hideTopicDrop()

      @$(".search").addClass('is-open')
      @$(".browse").removeClass('is-open')
      setTimeout (-> @$(".post-search-field").focus()), 200

    toggleTopicDrop: (event) =>
      event.preventDefault()
      event.stopPropagation()
      if @current_search != ""
        @clearSearch()
      @$(".search").removeClass('is-open')
      @$(".browse").addClass('is-open')
      @$(".browse").toggleClass('is-dropped')

      if @$(".browse").hasClass('is-dropped')
        @$(".browse-topic-drop-menu-wrapper").show()
        $(".browse-topic-drop-search-input").focus()
        $("body").bind "click", @toggleTopicDrop
        $("body").bind "keydown", @setActiveItem
      else
        @hideTopicDrop()

    hideTopicDrop: ->
      @$(".browse-topic-drop-menu-wrapper").hide()
      $("body").unbind "click", @toggleTopicDrop
      $("body").unbind "keydown", @setActiveItem

    # TODO get rid of this asap
    setTopicHack: (boardNameContainer) ->
      item = $(boardNameContainer).closest('a')
      boardName = item.find(".board-name").html()
      _.each item.parents('ul').not('.browse-topic-drop-menu'), (parent) ->
        boardName = $(parent).siblings('a').find('.board-name').html() + ' / ' + boardName
      @$(".current-board").html(@fitName(boardName))

    setTopic: (event) ->
      item = $(event.target).closest('a')
      boardName = item.find(".board-name").html()
      _.each item.parents('ul').not('.browse-topic-drop-menu'), (parent) ->
        boardName = $(parent).siblings('a').find('.board-name').html() + ' / ' + boardName
      @$(".current-board").html(@fitName(boardName))

    setSelectedTopic: (name) ->
      @$(".current-board").html(@fitName(name))

    getNameWidth: (name) ->
      test = $("<div>")
      test.css
        "font-size": @$(".current-board").css('font-size')
        opacity: 0
        position: 'absolute'
        left: -1000
        top: -1000
      $("body").append(test)
      test.html(name)
      width = test.width()
      test.remove()
      return width

    fitName: (name) ->
      @maxNameWidth = (@$el.width() * .8) - 50
      width = @getNameWidth(name)
      if width < @maxNameWidth
        return name
      path = (x.replace /^\s+|\s+$/g, "" for x in name.split("/"))
      while path.length > 1
        path.shift()
        partialName = "…/" + path.join("/")
        if  @getNameWidth(partialName) < @maxNameWidth
          return partialName
      rawName = path[0]
      name = "…/" + rawName
      while @getNameWidth(name) > @maxNameWidth
        rawName = rawName[0...rawName.length-1]
        name =  "…/" + rawName + "…"
      return name

    filterTopic: (event) ->
      if @current_search != ""
        @setTopic(event)
        @clearSearch @filterTopic, event
      else
        @setTopic(event)  # just sets the title for the dropdown
        item = $(event.target).closest('li')
        if item.find("span.board-name").data("discussion_id") == "#all"
          @discussionIds = ""
          @$(".post-search-field").val("")
          @retrieveAllThreads()
        else
          discussionIds = _.map item.find(".board-name[data-discussion_id]"), (board) -> $(board).data("discussion_id").id
          @retrieveDiscussions(discussionIds)

    retrieveDiscussion: (discussion_id, callback=null) ->
      url = DiscussionUtil.urlFor("retrieve_discussion", discussion_id)
      DiscussionUtil.safeAjax
        url: url
        type: "GET"
        success: (response, textStatus) =>
          @collection.current_page = response.page
          @collection.pages = response.num_pages
          @collection.reset(response.discussion_data)
          Content.loadContentInfos(response.content_info)
          @displayedCollection.reset(@collection.models)
          if callback?
            callback()

    retrieveDiscussions: (discussion_ids) ->
      @discussionIds = discussion_ids.join(',')
      url = DiscussionUtil.urlFor("search")
      DiscussionUtil.safeAjax
        data: { 'commentable_ids': @discussionIds }
        url: url
        type: "GET"
        success: (response, textStatus) =>
          @collection.current_page = response.page
          @collection.pages = response.num_pages
          @collection.reset(response.discussion_data)
          Content.loadContentInfos(response.content_info)
          @displayedCollection.reset(@collection.models)

    retrieveAllThreads: () ->
      url = DiscussionUtil.urlFor("threads")
      DiscussionUtil.safeAjax
        url: url
        type: "GET"
        success: (response, textStatus) =>
          @collection.current_page = response.page
          @collection.pages = response.num_pages
          @collection.reset(response.discussion_data)
          Content.loadContentInfos(response.content_info)
          @displayedCollection.reset(@collection.models)

    sortThreads: (event) ->
      @$(".sort-bar a").removeClass("active")
      $(event.target).addClass("active")
      @sortBy = $(event.target).data("sort")
      if @sortBy == "date"
        @displayedCollection.comparator = @displayedCollection.sortByDateRecentFirst
      else if @sortBy == "votes"
        @displayedCollection.comparator = @displayedCollection.sortByVotes
      else if @sortBy == "comments"
        @displayedCollection.comparator = @displayedCollection.sortByComments
      @displayedCollection.sort()

    performSearch: (event) ->
      if event.which == 13
        event.preventDefault()
        text = @$(".post-search-field").val()
        @searchFor(text)

    setAndSearchFor: (text) ->
      @showSearch()
      @$(".post-search-field").val(text)
      @searchFor(text)

    searchFor: (text, callback, value) ->
      @current_search = text
      url = DiscussionUtil.urlFor("search")
      DiscussionUtil.safeAjax
        $elem: @$(".post-search-field")
        data: { text: text }
        url: url
        type: "GET"
        $loading: $
        loadingCallback: =>
          @$(".post-list").html('<li class="loading"><div class="loading-animation"></div></li>')
        loadedCallback: =>
          if callback
            callback.apply @, [value]
        success: (response, textStatus) =>
          if textStatus == 'success'
            # TODO: Augment existing collection?
            @collection.reset(response.discussion_data)
            Content.loadContentInfos(response.content_info)
            @collection.current_page = response.page
            @collection.pages = response.num_pages
            # TODO: Perhaps reload user info so that votes can be updated.
            # In the future we might not load all of a user's votes at once
            # so this would probably be necessary anyway
            @displayedCollection.reset(@collection.models)

    clearSearch: (callback, value) ->
      @$(".post-search-field").val("")
      @searchFor("", callback, value)

    setActiveItem: (event) ->
      if event.which == 13
        $(".browse-topic-drop-menu-wrapper .focused").click()
        return
      if event.which != 40 && event.which != 38
        return

      event.preventDefault()

      items = $.makeArray($(".browse-topic-drop-menu-wrapper a").not(".hidden"))
      index = items.indexOf($('.browse-topic-drop-menu-wrapper .focused')[0])

      if event.which == 40
          index = Math.min(index + 1, items.length - 1)
      if event.which == 38
          index = Math.max(index - 1, 0)

      $(".browse-topic-drop-menu-wrapper .focused").removeClass("focused")
      $(items[index]).addClass("focused")

      itemTop = $(items[index]).parent().offset().top
      scrollTop = $(".browse-topic-drop-menu").scrollTop()
      itemFromTop = $(".browse-topic-drop-menu").offset().top - itemTop
      scrollTarget = Math.min(scrollTop - itemFromTop, scrollTop)
      scrollTarget = Math.max(scrollTop - itemFromTop - $(".browse-topic-drop-menu").height() + $(items[index]).height(), scrollTarget)
      $(".browse-topic-drop-menu").scrollTop(scrollTarget)

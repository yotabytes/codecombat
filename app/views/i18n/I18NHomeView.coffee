RootView = require 'views/kinds/RootView'
template = require 'templates/i18n/i18n-home-view'
CocoCollection = require 'collections/CocoCollection'

LevelComponent = require 'models/LevelComponent'
ThangType = require 'models/ThangType'
Level = require 'models/Level'
Achievement = require 'models/Achievement'

languages = _.keys(require 'locale/locale').sort()
PAGE_SIZE = 100

module.exports = class I18NHomeView extends RootView
  id: "i18n-home-view"
  template: template

  events:
    'change #language-select': 'onLanguageSelectChanged'

  constructor: (options) ->
    super(options)
    @selectedLanguage = me.get('preferredLanguage', true)

    #-
    @aggregateModels = new Backbone.Collection()
    project = ['name', 'components.original', 'i18nCoverage', 'slug']

    @thangTypes = new CocoCollection([], { url: '/db/thang.type?view=i18n-coverage', project: project, model: ThangType })
    @components = new CocoCollection([], { url: '/db/level.component?view=i18n-coverage', project: project, model: LevelComponent })
    @levels = new CocoCollection([], { url: '/db/level?view=i18n-coverage', project: project, model: Level })
    @achievements = new CocoCollection([], { url: '/db/achievement?view=i18n-coverage', project: project, model: Achievement })

    for c in [@thangTypes, @components, @levels, @achievements]
      c.skip = 0
      c.fetch({data: {skip: 0, limit: PAGE_SIZE}, cache:false})
      @supermodel.loadCollection(c, 'documents')
      @listenTo c, 'sync', @onCollectionSynced


  onCollectionSynced: (collection) ->
    for model in collection.models
      model.i18nURLBase = switch model.constructor.className
        when "ThangType" then "/i18n/thang/"
        when "LevelComponent" then "/i18n/component/"
        when "Achievement" then "/i18n/achievement/"
        when "Level" then "/i18n/level/"
    getMore = collection.models.length is PAGE_SIZE
    @aggregateModels.add(collection.models)
    @render()

    if getMore
      collection.skip += PAGE_SIZE
      collection.fetch({data: {skip: collection.skip, limit: PAGE_SIZE}})

  getRenderData: ->
    c = super()
    @updateCoverage()
    c.languages = languages
    c.selectedLanguage = @selectedLanguage
    c.collection = @aggregateModels
    c

  updateCoverage: ->
    selectedBase = @selectedLanguage[..2]
    relatedLanguages = (l for l in languages when l.startsWith(selectedBase) and l isnt @selectedLanguage)
    for model in @aggregateModels.models
      @updateCoverageForModel(model, relatedLanguages)
      model.generallyCovered = true if @selectedLanguage.startsWith 'en'

  updateCoverageForModel: (model, relatedLanguages) ->
    model.specificallyCovered = true
    model.generallyCovered = true
    coverage = model.get('i18nCoverage')

    if @selectedLanguage not in coverage
      model.specificallyCovered = false
      if not _.any((l in coverage for l in relatedLanguages))
        model.generallyCovered = false
        return

  afterRender: ->
    super()
    @addLanguagesToSelect(@$el.find('#language-select'), @selectedLanguage)

  onLanguageSelectChanged: (e) ->
    @selectedLanguage = $(e.target).val()
    @render()
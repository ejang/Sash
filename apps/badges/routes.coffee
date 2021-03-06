Badge = require '../../models/badge'
User = require '../../models/user'
Organization = require '../../models/organization'
authenticate = require '../middleware/authenticate'

util = require 'util'
fs = require 'fs'


routes = (app) ->
  app.namespace '/badges', authenticate, ->
    #INDEX
    app.get '/', (req, res) ->
      next() if !req.org
      orgId = req.org.id
      query = Badge.where('issuer_id', orgId)
      if req.query.tags?
        query.in('tags', req.query.tags)
      query.exec (err, badges)->
        if req.xhr || req.params.format == 'json'
          formatResponse(req, res, badges)
        else
          res.render "#{__dirname}/views/index",
            badges: badges
            orgId: orgId
            org: req.org

    #NEW
    app.get '/new', (req, res) ->
      if req.org
        orgId = req.org.id
      res.render "#{__dirname}/views/new",
        badge: new Badge
        orgId: orgId

    #CREATE
    app.post '/', (req, res, next) ->
      badge = new Badge req.body.badge
      badge.attach 'image', req.files.badge.image, (err)->
        next(err) if err
        badge.save (err, doc) ->
          next(err) if err
          req.flash 'info', 'Badge saved successfully!'
          res.redirect '/badges'

    #SHOW
    app.get '/:id.:format?', (req, res) ->
      Badge.findById req.params.id, (err, badge) ->
        if req.params.format == 'json'
          formatBadgeResponse(req, res, badge)
        else
          res.render "#{__dirname}/views/show",
            badge: badge
            issuer: badge.issuer()

    #SHOW
    app.get '/:id/edit', (req, res) ->
      Badge.findById req.params.id, (err, badge) ->
        res.render "#{__dirname}/views/edit",
          badge: badge
          issuer: badge.issuer()
          orgId: req.org.id

    #UPDATE
    app.put '/:id', (req, res, next) ->
      if req.files.badge.image.length > 0
        Badge.findById req.params.id, (err, badge)->
          badge.attach 'image', req.files.badge.image, (err)->
            next(err) if err
            badge.set(req.body.badge)
            badge.save (err, doc) ->
              next(err) if err
              req.flash 'info', 'Badge saved successfully!'
              res.redirect '/badges'
      else
        Badge.findById req.params.id, (err, badge)->
          badge.set(req.body.badge)
          badge.save (err, doc) ->
            next(err) if err
            req.flash 'info', 'Badge saved successfully!'
            res.redirect '/badges'


    #DELETE
    app.del '/:id', (req, res, next) ->
      Badge.findById req.params.id, (err, doc) ->
        doc.remove (err) ->
          if req.xhr
            res.send JSON.stringify(success: true),
              "Content-Type": "application/json"
          else
            req.flash 'info', 'Badge Destroyed!'
            res.redirect '/badges'

    app.post '/issue/:slug', (req, res, next) ->
      username = req.body.username
      Badge.findOne slug: req.params.slug, (err, badge) ->
        next(err) if err

        User.findOrCreate username,
          {issuer_id: badge.issuer_id, tags: req.query.tags},
          (err, user) ->
            user.earn badge, (err, response) ->
              next(err) if err
              res.send JSON.stringify(response),
                'content-type': 'application/json'

    # app.get '/issue/:slug', (req, res, next) ->
    #   username = req.query.username
    #   Badge.findOne slug: req.params.slug, (err, badge) ->
    #     next(err) if err

    #     User.findOrCreate username,
    #       {issuer_id: badge.issuer_id, tags: req.query.tags},
    #       (err, user) ->
    #         next(err) if err
    #         user.earn badge, (err, response) ->
    #           next(err) if err
    #           res.send JSON.stringify(response),
    #             'content-type': 'application/json'

formatBadgeResponse = (req, res, badge) ->
  cb = req.query.callback
  assertionPromise = badge.assertion()
  if cb
    assertionPromise.on 'complete', (assertion)->
      res.send "#{cb}(#{JSON.stringify(assertion)})",
        'content-type': 'application/javascript'
  else
    res.send assertionPromise,
      'content-type': 'application/json'


module.exports = routes


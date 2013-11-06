Deployer = require '../deployer'
W = require 'when'
fn = require 'when/function'
request = require 'request'
prompt = require 'prompt'
shipfile = require('../../shipfile')
_ = require 'underscore'

class Siteleaf extends Deployer

  constructor: (@path) ->
    super
    @name = 'Siteleaf'
    @config =
      api_key: null
      api_secret: null

      # optional global config
      # - site_id: site ID from Siteleaf API

  configure: (data, cb) ->
    @config = data.siteleaf

    if !@config.site_id
      get_sites_list.call(@)
      .then(sync(select_site, @))
      .then(sync(update_shipfile, @))
      .otherwise(console.error)
      .then(cb)
    else
      cb()

  deploy: (cb) ->
    @debug.log "deploying #{@path} to Siteleaf..."

    # fn.call(upload_files.bind(@))
    # .otherwise((err) -> cb(err))
    # .then((res) -> cb(null, res))

  destroy: (cb) ->
    @debug.log "removing site_id from Siteleaf conf files..."
    
    conf = {}
    conf.siteleaf = @config
    delete conf.siteleaf['site_id']
    shipfile.update(@path, conf)

    # @debug.log "removing test files from Siteleaf..."
    # client.rm(@config.target, cb)


  # 
  # @api private
  # 

  get_sites_list = ->
    deferred = W.defer()
    auth = {'auth': {'user': @config.api_key, 'pass': @config.api_secret}}

    request.get "https://api.siteleaf.com/v1/sites.json", auth, (err, res, body) ->
      if err then return deferred.reject(err)
      deferred.resolve(body)
    
    return deferred.promise

  select_site = (sites) =>
    deferred = W.defer()
    prompt.start()
    for opt in JSON.parse(sites)
      property = 
        name: 'yesno'
        message: "Deploy to \"#{opt.domain}\" ?"
        validator: /y[es]*|n[o]?/
        default: 'no'

      prompt.get property, (err, result) =>
        if err then return deferred.reject(err)
        test = new RegExp("y[es]?").test(result.yesno)
        if test 
          deferred.resolve(opt.id)

    return deferred.promise

  update_shipfile = (site_id) ->
    @debug.log "updating shipfile with access token..."
    @config.site_id = site_id
    
    conf = {}
    conf.siteleaf = @config
    shipfile.update(@path, conf)

  sync = (func, ctx) ->
    fn.lift(func.bind(ctx))

module.exports = Siteleaf

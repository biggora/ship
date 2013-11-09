require 'colors'
Deployer = require '../deployer'
path = require 'path'
fs = require 'fs'
shell = require 'shelljs/global'
readdirp = require 'readdirp'
W = require 'when'
fn = require 'when/function'
async = require 'async'

class Github extends Deployer

  constructor: (@path) ->
    super
    @name = 'Github Pages'
    @slug = 'gh-pages'
    @config =
      target: null

    @errors = 
      not_installed: 'You must install git - see http://git-scm.com'
      remote_origin: 'Make sure you have a remote origin branch for github'
      make_commit: 'You need to make a commit before deploying'

  configure: (data, cb) ->
    @config.target = path.join()
    @root = path.join(process.cwd(), @config.target)
    @folder = if @path == process.cwd() then @config.target else @path
    @target = if @path != process.cwd() then path.join(process.cwd(), @path) else process.cwd()
    cb()

  deploy: (cb) ->
    check_install_status.call(@)
    .then(move_to_gh_pages_branch.bind(@))
    .then(remove_source_files.bind(@))
    .then(dump_public_to_root.bind(@))
    .then(push_code.bind(@))
    .otherwise((err) -> console.error(err))
    .ensure(cb)


  check_install_status = ->
    deferred = W.defer()

    return deferred.reject(@errors.not_installed) if not which('git')
    return deferred.reject(@errors.remote_origin) if not execute('git remote | grep origin')
    
    @original_branch = execute('git rev-parse --abbrev-ref HEAD')
    if not @original_branch then return deferred.reject(@errors.make_commit)
    @debug.log "starting on branch \"#{@original_branch}\""

    deferred.resolve()

  move_to_gh_pages_branch = ->
    deferred = W.defer()

    if execute('git branch | grep gh-pages')
      @debug.log 'deleting existing gh-pages branch'
      execute('git branch -D gh-pages')

    @debug.log 'switching to gh-pages branch'
    execute('git checkout -b gh-pages')

    deferred.resolve()

  remove_source_files = ->
    deferred = W.defer()

    # don't delete anything if asked to ship root folder
    if @target == @root then return deferred.resolve()

    @debug.log 'removing extra source files'
    opts = { root: @root, directoryFilter: ["!#{@folder}", '!.git'], fileFilter: ['!*.conf'] };

    readdirp opts, (err, res) ->
      if err then return deferred.reject(err)
      async.map res, delete_files.bind(@), (err) ->
        if err then return deferred.reject(err)
        deferred.resolve()


  dump_public_to_root = ->
    deferred = W.defer()

    # move on if shipping root folder
    if @target == @root then return deferred.resolve()

    target = path.join(@target, '*')
    execute("mv -f #{path.resolve(target)} #{@config.target}");
    rm '-rf', @target
    rm '*.conf'

    deferred.resolve()

  push_code = ->
    deferred = W.defer()

    @debug.log 'committing project to git'
    execute 'git add --all .'
    execute 'git commit -a -m "deploying to gh-pages"'

    @debug.log 'pushing to origin/gh-pages'
    execute "git push origin gh-pages --force"

    @debug.log "switching back to #{@original_branch} branch"
    execute "git checkout #{@original_branch}"
 
    @debug.log 'deployed to github pages'
    
    deferred.resolve()

  delete_files = (res, cb) ->
    rm(f.path) for f in res.files
    rm('-rf', d.path) for d in res.directories
    cb()
      

  # 
  # @api private
  # 

  execute = (input) ->
    cmd = exec(input, { silent: true });
    if cmd.code > 0 or cmd.output == '' then false else cmd.output.trim()

module.exports = Github

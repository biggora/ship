fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'
deployers = require './deployers'

class ArgsParser

  constructor: (args, env) ->
    args ?= []

    @path = process.cwd()
    @cargo = path.join(@path)
    @folder = null

    @errors =
      missing_deployer: "Make sure to specify a deployer!"
      deployer_not_found: "I don't think we have that deployer in stock :("
      path_nonexistant: "It doesn't look like you have specified a path to a folder"

    if args.length < 1

      # no args, deploy all from conf file if present
      config = find_conf_file(env)

      if not config then return new Error(@errors.missing_deployer)
      return { path: @path, cargo: @cargo, config: config, folder: @folder, deployer: false }

    if args.length == 1
      @folder = args[0]
      @cargo = path.join(@cargo, @folder)

      # if the arg passed is a deployer, assume path is cwd
      if is_deployer(@folder) then return { path: @path, cargo: @cargo, folder: @folder, config: find_conf_file(env), deployer: @folder }

      # if the arg passed is not a deployer, assume it's a path
      if not path_exists(@folder) then return new Error(@errors.path_nonexistant)
      config = find_conf_file(env)

      if not config then return new Error(@errors.missing_deployer)
      return { path: @path, cargo: @cargo, config: config, folder: @folder, deployer: false }

    if args.length > 1
      @folder = args[0]
      @cargo = path.join(@cargo, @folder)

      # two args, both path and deployer must exist
      if not path_exists(@folder) then return new Error(@errors.path_nonexistant)
      if not is_deployer(args[1]) then return new Error(@errors.deployer_not_found)
      return { path: @path, cargo: @cargo, config: find_conf_file(env), folder: @folder, deployer: args[1] }

    
  # 
  # @api private
  # 
  
  find_conf_file = (env) ->
    env = if env? and env != '' then ".#{env}" else ''
    cnf = path.join(@path, "ship#{env}.conf")

    if not fs.existsSync(cnf) then return false
    return yaml.safeLoad(fs.readFileSync(cnf, 'utf8'))

  is_deployer = (arg) ->
    Object.keys(deployers).indexOf(arg) > -1

  path_exists = (p) ->
    fs.existsSync(p)

module.exports = ArgsParser

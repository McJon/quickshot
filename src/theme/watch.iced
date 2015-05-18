
helpers = require('../helpers')

chokidar = require('chokidar')
inquirer = require('inquirer')
colors = require('colors')
fs = require('fs')
path = require('path')
request = require('request')
mkdirp = require('mkdirp')
sass = require('node-sass')
parser = require('gitignore-parser')

exports.run = (argv, done) ->

  await helpers.loadConfig(defer(err, config))
  if err? then done(err)

  if config.ignore_file
    ignore = parser.compile(fs.readFileSync(config.ignore_file, 'utf8'))

  await helpers.getTarget(config, argv, defer(err, target))
  if err? then return done(err)

  await helpers.getShopPages(target, defer(err, pages))
  if err? then return done(err)

  watcher = chokidar.watch('./', {
    ignored: /[\/\\]\./
    persistent: true
    ignoreInitial: true
    usePolling: true
    interval: 250
    binaryInterval: 250
    cwd: path.join(process.cwd(), 'theme')
  })

  watcher.on('all', (event, filepath) ->
    extension = path.extname(filepath).substr(1)

    # filepath = path.join('theme', filepath)

    # Ignore hidden files
    if filepath.match(/^\..*$/) then return

    # Ignore paths configured in ignore file
    if config.ignore_file
      if ignore.denies(filepath) then return

    switch event
      when 'add', 'change'

        if filepath.match(/[\(\)]/)
          return console.log colors.red("Filename may not contain parentheses, please rename - \"#{filepath}\"")

        if config.compile_scss and filepath.match(/\.scss$/)
          mainscss = config.primary_scss_file
          targetscss = mainscss.replace('.scss', '.css')
          console.log colors.yellow("Compiling Sass: \"#{mainscss}\" -> \"#{targetscss}\"")
          await sass.render({file: path.join('theme', mainscss), outFile: path.join('theme', targetscss)}, defer(err, result))
          if err? then done(err)
          await fs.writeFile(path.join('theme', targetscss), result.css, defer(err))
          if err? then done(err)

        await fs.readFile(path.join('theme', filepath), defer(err, data))
        await helpers.shopifyRequest({
          filepath: filepath
          method: 'put'
          url: "https://#{target.api_key}:#{target.password}@#{target.domain}.myshopify.com/admin/themes/#{target.theme_id}/assets.json"
          json: {
            asset: {
              key: filepath
              attachment: data.toString('base64')
            }
          }
        }, defer(err, res, assetsBody))
        if err? then console.log colors.red(err)

        unless err? then console.log colors.green("Added/Updated #{filepath}")

      when 'unlink'
        await helpers.shopifyRequest({
          method: 'delete'
          url: "https://#{target.api_key}:#{target.password}@#{target.domain}.myshopify.com/admin/themes/#{target.theme_id}/assets.json"
          qs: {
            asset: {key: filepath}
          }
        }, defer(err, res, assetsBody))
        if err? then console.log colors.red(err)

        console.log colors.green("Deleted #{filepath}")
  )

  console.log "Watching Theme..."
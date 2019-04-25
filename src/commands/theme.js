
// let _ = require('lodash')
let path = require('path')
let requireAll = require('require-all')

/* global VERSION */

var HELPTEXT = `

    Quickshot theme ${VERSION}
    ==============================

    Commands:
      quickshot theme upload [options]              Upload theme files
      quickshot theme download [options]            Download theme files
      quickshot theme watch [options]               Watch theme folder, compile and synchronize changes automatically
      quickshot theme                               Show this screen.

    Options:
      --target=[targetname]                         Explicitly select target for upload/download/watch
      --sync                                        Enable experimental two-way sync for watch

`

module.exports = async function (argv) {
  let command = argv['_'].shift()

  let commands = requireAll({
    dirname: path.join(__dirname, 'theme')
  })

  if (commands[command] == null) {
    console.log(HELPTEXT)
  } else {
    return commands[command](argv)
  }
}
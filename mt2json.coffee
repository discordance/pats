Fs = require('graceful-fs')
Junk = require 'junk'
JSON5 = require 'json5'
Slug = require 'slug'


Fs.readdir __dirname+"/raw", (err, files) ->
  errs = 0
  mts = (files.filter Junk.not)
  mts.forEach (file, i) ->
    #return if i > 1

    Fs.readFile __dirname+"/raw/"+file, (err, ff)->
      if !err
        str = ff.toString 'utf8'
        reg = /\s\=\s/gi
        str = str.replace reg, ': '

        floats_r = /\s([-+]*\d+\.\d+)/g
        ints_r = /\s(\d+)\n/g
        div_r = /\s(\d+\/\d+)/g
        keys_r = /(\w+):/g
        words_r = /: ([-+]*\w+)/g
        mutes_r = /\"Mutes\":\s\{.+}/g
        pats_r = /([#-]{16})/g

        shit_r = /Hz|sm|ms|dB|%/g
        str = str.replace shit_r, ','
        str = str.replace div_r, " 16"
        str = str.replace keys_r, "\"$1\":"
        str = str.replace floats_r, "\"$1\""
        str = str.replace ints_r, "\"$1\""
        str = str.replace words_r, ": \"$1\""
        str = str.replace mutes_r, ""
        str = str.replace /\"\n/g, ",\n"
        str = str.replace pats_r, "\"$1\""
        str = str.replace /(\"\r)/g, "\",\r"
        str = str.replace /}/g, "},"
        str = '{'+str+'}'

        try
          obj = JSON5.parse str
        catch err
          errs++
          console.log errs
          return
        name = Slug(obj.MicroTonicPresetV3.Name).toLowerCase()
        Fs.writeFile __dirname+"/json_pats/"+name+'.json', JSON.stringify(obj.MicroTonicPresetV3,null,2), 'utf8', (err)->
      else
        errs++
        console.log err

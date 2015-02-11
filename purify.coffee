Fs = require('graceful-fs')
Junk = require 'junk'
Async = require 'async'
Clusterfck = require "clusterfck"
Brain = require 'brain'

Net = new Brain.NeuralNetwork({hiddenLayers:[64]})

stringit = (obj)->
  str = ""
  str+= Math.round(obj['osc_freq']) + "|"
  str+= Math.round(obj['osc_lvl']) + "|"
  str+= Math.round(obj['noise_lvl']) + "|"
  ptr = obj['patterns']['a'].join().replace(/0/g,'.')
  ptr = ptr.replace(/,/g,'')
  ptr = ptr.replace(/1|2/g,'x')
  str+= ptr
  return str

mean = (array) ->
 return 0 if array.length is 0
 sum = array.reduce (s,i) -> s += i
 sum / array.length

isk = (line) ->
  res = true
  if !line[0]
    res = false
  if mean(line) > 0.6
    res = false
  res

iss = (line) ->
  res = true
  if mean(line) > 0.3
    res = false
  res

labels = {
  0:'k1',
  1:'k2',
  2:'t1',
  3:'t2',
  4:'sn',
  5:'h1',
  6:'h2',
  7:'h3',
  8:'r1',
  9:'r2'
}
centroids = [
    [ 2, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 40, 0 ], # kick
    [ 2, 0, 0, 0, 1, 0, 0, 2, 0, 0, 0, 0, 2, 0, 0, 0, 20, 0 ], # kick
    [ 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 64, 0 ], # tom
    [ 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 160, 0 ], # tom
    [ 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 200, 100 ], # sn
    [ 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 5000, 160 ], # h
    [ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 10000, 180 ],# hh
    [ 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 10000, 180 ],# hhh
    [ 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8000, 180 ], # random centroids
    [ 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 2000, 100 ] # random
  ]

kmeans = new Clusterfck.Kmeans(centroids)

Fs.readdir __dirname+"/json_pats", (err, files) ->
  errs = 0
  jsons = (files.filter Junk.not)
  # !
  purified = []

  sample = []
  Async.each jsons, (file, next)->
    Fs.readFile __dirname+"/json_pats/"+file, (err, ff)->
      preset = JSON.parse(ff.toString('utf8'))
      obj = {name:file.replace(".json",""), tracks:{}}

      for k, v of preset.DrumPatches
        obj['tracks'][k] = {}
        obj['tracks'][k]['osc_freq'] = parseFloat preset.DrumPatches[k].OscFreq
        obj['tracks'][k]['osc_lvl'] = parseFloat preset.DrumPatches[k].OscVel
        obj['tracks'][k]['noise_lvl'] = parseFloat preset.DrumPatches[k].NVel
        obj['tracks'][k]['noise_filt'] = parseFloat preset.DrumPatches[k].NFilFrq
        obj['tracks'][k]['patterns'] = {}

        for kk, vv of preset.Patterns
          pat = preset.Patterns[kk][k]
          patarr = []

          # trigs
          for i in [0..pat.Triggers.length-1]
            if pat.Triggers[i] is '#'
              patarr.push 1
            else
              patarr.push 0
          # accents
          for i in [0..pat.Accents.length-1]
            if pat.Accents[i] is '#'
              patarr[i]++
          obj['tracks'][k]['patterns'][kk] = patarr

        # classify
        line = JSON.parse(JSON.stringify(obj['tracks'][k]['patterns']['a']))
        line.push Math.round obj['tracks'][k]['osc_freq']
        #line.push Math.round obj['tracks'][k]['osc_lvl']
        line.push Math.round obj['tracks'][k]['noise_lvl']
        classed = labels[kmeans.classify(line)]
        if classed is 'k1' or classed is 'k2'
          if !isk(line.slice(0,16))
            classed = 'r2'
        if classed is 'sn'
          if !iss(line.slice(0,16))
            classed = 'r1'
        obj['tracks'][k]['class'] = classed

      purified.push obj
      next()
  , ()->
    genebad = ()->
      pos = [0,0.5,1]
      res = []
      for [0..63]
        res.push pos[Math.floor(Math.random()*3)]
      res
    # write file, then performs braining
    Fs.writeFile __dirname+"/json_pure/pure.json", JSON.stringify(purified,null,2), 'utf8', (err)->
      if !err
        goods = []
        bads = []
        purified.forEach (preset) ->
          tracks = preset['tracks']
          train = {}
          for k, v of preset['tracks']
            pat = v['patterns']['a']
            if v['class'] is 'k1' or v['class'] is 'k2'
              train['k'] = pat
            if v['class'] is 't1' or v['class'] is 't2'
              train['t'] = pat
            if v['class'] is 'sn' or v['class'] is 'r1' or v['class'] is 'r2'
              train['s'] = pat
            if v['class'] is 'h1' or v['class'] is 'h2' or v['class'] is 'h3'
              train['h'] = pat
          if train.h and train.k and train.t and train.s
            line = []
            #make it processable
            #console.log train.k
            line=line.concat train.k
            line=line.concat train.t
            line=line.concat train.s
            line=line.concat train.h
            line = (it/2 for it in line)
            goods.push line
            bads.push genebad()

        train = []
        console.log "train sets", goods.length, bads.length
        goods.forEach (it)->
          ob = {input:it,output:[1]}
          train.push ob
        bads.forEach (it)->
          ob = {input:it,output:[0]}
          train.push ob

        res = Net.train train, {errorThresh: 0.0005, learningRate: 0.05, log: true, iterations: 20000}
        console.log "res", res
        netjson = Net.toJSON()
        Fs.writeFile __dirname+"/nets/4tracks64.json", JSON.stringify(netjson,null,2), 'utf8', (err)->

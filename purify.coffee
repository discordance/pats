Fs = require('graceful-fs')
Junk = require 'junk'
Async = require 'async'
Clusterfck = require "clusterfck"
Brain = require 'brain'

Net = new Brain.NeuralNetwork({hiddenLayers:[64,32,64]})

rotate = (arr, reverse) ->
  if reverse
    arr.push arr.shift()
  else
    arr.unshift arr.pop()
  arr

shuffle = (array) ->
  counter = array.length
  temp = undefined
  index = undefined
  # While there are elements in the array
  while counter > 0
    # Pick a random index
    index = Math.floor(Math.random() * counter)
    # Decrease counter by 1
    counter--
    # And swap the last element with it
    temp = array[counter]
    array[counter] = array[index]
    array[index] = temp
  array

bjorklund = (steps, pulses) ->
  steps = Math.round(steps)
  pulses = Math.round(pulses)
  if pulses > steps or pulses == 0 or steps == 0
    return new Array
  pattern = []
  counts = []
  remainders = []
  divisor = steps - pulses
  remainders.push pulses
  level = 0
  loop
    counts.push Math.floor(divisor / remainders[level])
    remainders.push divisor % remainders[level]
    divisor = remainders[level]
    level += 1
    if remainders[level] <= 1
      break
  counts.push divisor
  r = 0

  build = (level) ->
    r++
    if level > -1
      i = 0
      while i < counts[level]
        build level - 1
        i++
      if remainders[level] != 0
        build level - 2
    else if level == -1
      pattern.push 0
    else if level == -2
      pattern.push 1
    return

  build level
  pattern.reverse()
  while !pattern[0]
    rotate pattern
  pattern

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
 sum = 0
 array.forEach (e)->
   if e
     sum++
 sum

isk = (line) ->
  res = true
  if !line[0]
    res = false
  if mean(line) > 7
    res = false
  res

iss = (line) ->
  res = true
  if mean(line) > 5
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

        # we need to re-order a bit
        if classed is 'k1' or classed is 'k2'
          if !isk(line.slice(0,16))
            classed = 'r2'
        else if classed is 'sn'
          if !iss(line.slice(0,16))
            classed = 'r1'

        obj['tracks'][k]['class'] = classed

      purified.push obj
      next()
  , ()->

    # genebad = (max = 64)->
    #   pos = [0, 0, 0.5, 1] # increase the possibility of 0s
    #   res = []
    #   for [0..(max-1)]
    #     res.push pos[Math.floor(Math.random()*4)]
    #   res
    # make better noise
    genebad = ()->
      kpos = [0,0.5,0.5,0.5,1]
      tpos = [0,0.5,1,1,1]
      spos = [0,0.5,0.5,0.5,1,1]
      hpos = [0,0,0,0,0,0.5,1,1]
      res = []
      # k
      for i in [0..15]
        if !i and (0.5-Math.random())
          res.push 0
        else
          res.push kpos[Math.floor(Math.random()*5)]
      # t
      for i in [0..15]
        res.push tpos[Math.floor(Math.random()*5)]
      # s
      for i in [0..15]
        res.push spos[Math.floor(Math.random()*6)]
      # h
      for i in [0..15]
        res.push hpos[Math.floor(Math.random()*8)]
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
              #console.log pat
              train['k'] = pat
              #train['k'] = [ 2, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]
            if v['class'] is 't1' or v['class'] is 't2'
              train['t'] = pat
              #train['t'] = [ 0, 2, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0]
            if v['class'] is 'sn' or v['class'] is 'r1' or v['class'] is 'r2'
              train['s'] = pat
              #train['s'] = [ 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0]
            if v['class'] is 'h1' or v['class'] is 'h2' or v['class'] is 'h3'
              train['h'] = pat
              #train['h'] = [ 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 2, 0, 0]
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
        console.log bjorklund 16, 5
        console.log "train sets", goods.length, bads.length
        goods.forEach (it)->
          ob = {input:it,output:[1]}
          train.push ob
        bads.forEach (it)->
          ob = {input:it,output:[0]}
          train.push ob

        train = shuffle train
        res = Net.train train, {errorThresh: 0.001, learningRate: 0.1, log: true, iterations: 20000}
        console.log "res", res
        netjson = Net.toJSON()
        Fs.writeFile __dirname+"/nets/4tracks64.json", JSON.stringify(netjson,null,2), 'utf8', (err)->

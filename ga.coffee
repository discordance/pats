Fs = require('graceful-fs')
Sleep = require 'sleep'
_ = require 'lodash'
Brain = require 'brain'
Net = new Brain.NeuralNetwork()


Fs.readFile __dirname+"/nets/4tracks64.json", (err, ff)->
  json = ff.toString('utf8')
  Net.fromJSON(JSON.parse(json))
  net_func = Net.toFunction()

  rnd = Math.random
  floor = Math.floor
  # fitness func
  fitness = (to_test)->
    net_func(to_test)['0']

  # rand func
  genebad = (max)->
    pos = [0,0.5,1]
    res = []
    for [0..(max-1)]
      res.push pos[Math.floor(Math.random()*3)]
    res

  # render
  render = (seq)->
    str = ""
    for i in [0..63]
      if i%16 is 0
        str+='\n'
      if seq[i] is 1
        str+='X'
      if seq[i] is 0.5
        str+='x'
      if seq[i] is 0
        str+='.'
    str+= "\n"
    return str

  # rnd mutator
  mutate = (ori)->
    sixtyfour = ori.slice()
    scales = [4,8,16,32]
    scale = scales[floor(rnd()*4)]
    mutation = genebad(scale)
    sixtyfour = sixtyfour.concat mutation
    sixtyfour = sixtyfour.slice(-64)


  # infantify
  infantify = (parent1, parent2)->
    res = []
    par = [parent1, parent2]
    rng = [0, 8, 16, 24, 32, 48, 56]
    for [0..7]
      r = rng[floor(rnd()*rng.length)]
      p = par[floor(rnd()*2)]
      res = res.concat p.slice r, r+8
    res
    
  pop = []
  pop_size = 128
  chunk = (pop_size/4)
  max_gen = 50
  generation = 0

  for [0..pop_size-1]
    pop.push genebad(64)

  while generation < max_gen
    scores = []
    _.each pop, (line,i) ->
      scores.push
        score: fitness line
        idx: i
    scores = _.sortBy scores, 'score'
    sorted = (pop[i.idx] for i in scores)
    console.log generation, scores[scores.length-1].score
    # new pop
    # keep best chunk
    newpop = sorted.slice -chunk
    babies = []
    mutates = []
    newbies = []
    # make chunk random babies
    for i in [0..(chunk-1)]
      r1 = floor(rnd()*chunk)
      r2 = floor(rnd()*chunk)
      babies.push infantify newpop[r1], newpop[r2]
    # mutate
    for i in [0..(chunk-1)]
      mutates.push mutate newpop[i]
    # newbs
    for i in [0..(chunk-1)]
      newbies.push genebad 64
    # mix
    newpop = newpop.concat babies
    newpop = newpop.concat mutates
    newpop = newpop.concat newbies

    # nex gen
    pop = newpop

    Sleep.usleep 10000
    generation++

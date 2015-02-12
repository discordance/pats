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
    pos = [0, 0, 0.5, 1] # increase the possibility of 0s
    res = []
    for [0..(max-1)]
      res.push pos[Math.floor(Math.random()*4)]
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
    scales = [2,4,8,16,32]
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

  elite = (pop_size/4)
  mutation = (pop_size/8)
  crossover = (pop_size/2)
  newb = (pop_size/8)

  max_gen = 10
  generation = 0

  dup = []
  for [0..pop_size-1]
    gen = genebad(64)
    pop.push gen

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
    newpop = sorted.slice -elite
    babies = []
    mutates = []
    newbies = []
    # make chunk random babies
    for i in [0..(crossover-1)]
      r1 = floor(rnd()*elite)
      r2 = floor(rnd()*elite)
      babies.push infantify newpop[r1], newpop[r2]
    # mutate
    for i in [0..(mutation-1)]
      mutates.push mutate newpop[i%elite]
    # newbs
    for i in [0..(newb-1)]
      newbies.push genebad 64
    # mix
    newpop = newpop.concat babies
    newpop = newpop.concat mutates
    newpop = newpop.concat newbies

    # nex gen
    pop = newpop

    Sleep.usleep 5000
    generation++

  scores = []
  _.each pop, (line,i) ->
    scores.push
      score: fitness line
      idx: i
      render: render(line)
  scores = _.sortBy(scores, 'score').reverse()
  for i in [0..1]
    console.log scores[i].render

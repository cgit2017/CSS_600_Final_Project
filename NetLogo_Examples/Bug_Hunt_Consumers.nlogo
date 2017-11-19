globals
[
  bugs-stride ;; how much a bug moves in each simulation step
  bug-size    ;; the size of the shape for a bug
  bug-reproduce-age ;; age at which bug reproduces
  bugs-born ;; number of bugs born
  bugs-died ;; number of bugs that died
  max-bugs-age
  min-reproduce-energy-bugs ;; how much energy, at minimum, bug needs to reproduce
  max-bugs-offspring ;; max offspring a bug can have

  max-plant-energy ;; the maximum amount of energy a plant in a patch can accumulate
  sprout-delay-time ;; number of ticks before grass starts regrowing
  grass-level ;; a measure of the amount of grass currently in the ecosystem
  grass-growth-rate ;; the amount of energy units a plant gains every tick from regrowth

  bugs-color
  grass-color
  dirt-color
]

breed [ bugs bug ]
breed [ disease-markers a-disease-marker] ;; visual cue, red "X" that bug has a disease and will die
breed [ embers ember] ;; visual cue that a grass patch is on fire

turtles-own [ energy current-age max-age female? #-offspring]

patches-own [ fertile?  plant-energy countdown]


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; setup procedures ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  set bugs-born 0
  set bugs-died 0

  set bug-size 1.2
  set bugs-stride 0.3
  set bug-reproduce-age 20
  set min-reproduce-energy-bugs 10
  set max-bugs-offspring 2
  set max-bugs-age 100
  set grass-level 0

  set sprout-delay-time 25
  set grass-growth-rate 10
  set max-plant-energy 100

  set bugs-color (violet )
  set grass-color (green)
  set dirt-color (white)
  set-default-shape bugs "bug"
  set-default-shape embers "fire"
  add-starting-grass
  add-bugs
  reset-ticks
end

to add-starting-grass
  let number-patches-with-grass (floor (amount-of-grassland * (count patches) / 100))
  ask patches [
      set fertile? false
      set plant-energy 0
    ]
  ask n-of number-patches-with-grass patches  [
      set fertile? true
      set plant-energy max-plant-energy / 2
    ]
  ask patches [color-grass]
end

to add-bugs
  create-bugs initial-number-bugs  ;; create the bugs, then initialize their variables
  [
    set color bugs-color
    set size bug-size
    set energy 20 + random 20 - random 20 ;; randomize starting energies
    set current-age 0  + random max-bugs-age     ;; start out bugs at different ages
    set max-age max-bugs-age
    set #-offspring 0
    setxy random world-width random world-height
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; runtime procedures ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
 if ticks >= 1000 and constant-simulation-length? [stop]
  ask bugs [
    bugs-live
    reproduce-bugs
    ]
  ask patches [
    set countdown random sprout-delay-time
    grow-grass
    ]   ;; only the fertile patches can grow grass
  fade-embers
  age-disease-markers
  tick
end

to remove-a-%-of-bugs
  ;; procedure for removing a percentage of bugs (when button is clicked)
  let number-bugs count bugs
  ask n-of floor (number-bugs * bugs-to-remove / 100) bugs [
    hatch 1 [
     set current-age  0
     set breed disease-markers
     set size 1.5
     set color red
     set shape "x"
     ]
    set bugs-died (bugs-died + 1)
    die
  ]
end

to start-fire
  let current-grass-patches patches with [fertile?]
  let current-burn-patches n-of floor ( (count current-grass-patches) * grass-to-burn-down / 100) current-grass-patches
  ask current-burn-patches [
    set countdown sprout-delay-time
    set plant-energy 0
    color-grass
    create-ember
    ]
end

to create-ember ;; patch procedure
  sprout 1 [
    set breed embers
    set current-age (round countdown / 4)
    set color [255 255 0 255]
    set size 1
    ]
end

to age-disease-markers
  ask disease-markers [
      set current-age (current-age  + 1)
      set size (1.5 - (1.5 * current-age  / 20))
      if current-age  > 25  or (ticks = 999 and constant-simulation-length?)  [die]
   ]
end

to fade-embers
  let ember-color []
  let transparency 0
  ask embers [
    set shape "fire"
    set current-age (current-age - 1)
    set transparency round floor current-age * 255 / sprout-delay-time
   ;; show transparency
    set ember-color lput transparency [255 155 0]
  ;;  show ember-color
    if current-age <= 0 [die]
    set color ember-color
  ]
end

to bugs-live
    move-bugs
    set energy (energy - 1)  ;; bugs lose energy as they move
    set current-age (current-age + 1)
    bugs-eat-grass
    death
end

to move-bugs
  rt random 50 - random 50
  fd bugs-stride
end

to bugs-eat-grass  ;; bugs procedure
  ;; if there is enough grass to eat at this patch, the bugs eat it
  ;; and then gain energy from it.
  if plant-energy > amount-of-food-bugs-eat  [
    ;; plants lose ten times as much energy as the bugs gains (trophic level assumption)
    set plant-energy (plant-energy - (amount-of-food-bugs-eat * 10))
    set energy energy + amount-of-food-bugs-eat  ;; bugs gain energy by eating

  ]
  ;; if plant-energy is negative, make it positive
  if plant-energy <=  amount-of-food-bugs-eat  [set countdown sprout-delay-time ]
end

to reproduce-bugs  ;; bugs procedure
  let number-new-offspring (random (max-bugs-offspring + 1)) ;; set number of potential offpsring from 1 to (max-bugs-offspring)
  if (energy > ((number-new-offspring + 1) * min-reproduce-energy-bugs)  and current-age > bug-reproduce-age)
  [
      set energy (energy - (number-new-offspring  * min-reproduce-energy-bugs))      ;;lose energy when reproducing --- given to children
      set #-offspring #-offspring + number-new-offspring
      set bugs-born bugs-born + number-new-offspring
      hatch number-new-offspring
      [
        set size bug-size
        set color bugs-color
        set energy min-reproduce-energy-bugs ;; split remaining half of energy amongst litter
        set current-age 0
        set #-offspring 0
        rt random 360 fd bugs-stride
      ]    ;; hatch an offspring set it heading off in a a random direction and move it forward a step
  ]
end

to death
  ;; die when energy dips below zero (starvation), or get too old
  if (current-age > max-age) or (energy < 0)
  [ set bugs-died (bugs-died + 1)
    die ]
end

to grow-grass  ;; patch procedure
  set countdown (countdown - 1)
  ;; fertile patches gain 1 energy unit per turn, up to a maximum max-plant-energy threshold
  if fertile? and countdown <= 0
     [set plant-energy (plant-energy + grass-growth-rate)
       if plant-energy > max-plant-energy
       [set plant-energy max-plant-energy]
       ]
  if not fertile?
     [set plant-energy 0]
  if plant-energy < 0 [set plant-energy 0 set countdown sprout-delay-time]
  color-grass
end

to color-grass
  ifelse fertile? [
    ifelse plant-energy > 0
    ;; scale color of patch from whitish green for low energy (less foliage) to green - high energy (lots of foliage)
    [set pcolor (scale-color green plant-energy  (max-plant-energy * 2)  0)]
    [set pcolor dirt-color]
    ]
  [set pcolor dirt-color]
end


; Copyright 2011 Uri Wilensky.
; See Info tab for full copyright and license.

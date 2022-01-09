patches-own[reward Qlist ]

breed [ cars car ]

globals [ave-reward r-episode episode bestProcess num-run]

cars-own [Qsa Hlist process]

to setup ;--this builds the environment
  ca
  let x max-pxcor
  let y max-pycor

  ;--patches are the individual states: set up color, reward, and inital Q(s,a) values
  ask patches [ set pcolor 9]           ;; set the background color
  ask patch -4 4 [set pcolor green - 2] ;; set the green color of the starting point
  ask patch 4 -4 [set pcolor green]

  ; add "obstacles" on the basis of 'num-obstacles-rate' from the interface
  if n-obstacles-rate > 0 [
    let i 1 + random (n-obstacles-rate - 1)
    while [i > 0]
    [ ; some obstacles in rows 3, 1, -1, -2
      ask patch (- 3 + random 6) 2 [ beutify-patch popolate-at-random-x-4 ]
      ask patch (- 4 + random 8) 1 [ beutify-patch popolate-at-random-x-4 ];; fill the central line with some obstacles
      ask patch (- 4 + random 8) -1 [ beutify-patch popolate-at-random-x-4 ];; fill the central line with some obstacles
      ask patch (- 5 + random 10) -2 [ beutify-patch popolate-at-random-x-4 ]
      set i i - 1
    ]
  ]

  ; set borders without any turtles and pcolor 8
  if any? turtles-on patches with [pxcor = min-pxcor or pxcor = max-pxcor][
    ask turtles-on patches with [pxcor = min-pxcor or pxcor = max-pxcor][die]
  ]
  ask patches with [pxcor = x or pxcor = (- x) or pycor = y or pycor = (- y)][set pcolor 8]

  ; vector for the shortest process
  set bestProcess []

  ; build the self-driving car
  create-cars 1
  [
    set shape "car" set color red - 1 setxy -4 4 set size 0.5 set Hlist [45 90 135 180 225 270 315 0]
  ]

  ; initialise first run
  init-run

  set num-run 1

  reset-ticks
end

; setup procedures to create obstacles in the environment
to popolate-at-random-x-4
  ask n-of random 4 neighbors4 [beutify-patch]
end

to-report select-a-shape
  let select-shape "tree"
  if random 2 = 1 [ set select-shape "house" ]
  set pcolor 8
  report select-shape
end

to beutify-patch
  if not any? other turtles-here [
    sprout 1 [ set shape select-a-shape ifelse shape = "tree" [set color 63 + random 5 ][set color 3 + random 5] set size 1.5]
  ]
end

to init-run  ;--initialise the next run
  setup-rewards
  ;--initailize Q(s,a) values for the patches
  ask patches [set Qlist [0 0 0 0 0 0 0 0]] ;--this list stores the reward values of the state-action mapping

  ;--intialize cars
  ask one-of cars
  [
    setxy -4 4
    set process []
    set process lput patch-here process
  ]
end

to setup-rewards
  ask patches [ifelse pcolor = 8 [set reward ( -10)][set reward 0]]
  ask patch 4 -4 [ set reward 10 ]
  if view-rewards? [ ask patches [set plabel reward] ]
end

to go
  tick ;-- number of episode

  while [num-run <= num-runs] [

    reset-ticks

    ask patches [ set Qlist [0 0 0 0 0 0 0 0] ] ;--this list stores the reward values of the state-action mapping

    while [ ticks <= num-episodes ]
    [
      set r-episode []

      ask cars [
        setxy -4 4
        set Qsa 0

        while [[reward] of patch-here = 0]
        [ ;-- search for maximun action
          let Qnew 1
          let Qmax 0
          let dirp 0

          let rand random-float 1

          while [Qnew != Qmax]
            [
              let dir one-of Hlist ;--pick random direction
              set dirp position dir Hlist ;--find dir's position in the Hlist array
              set Qmax max Qlist ;--get max from the Qlist values of the current patch
              set Qnew item dirp Qlist ;--find the value in Qlist with the same position as in the Hlist
            ]

          set heading item dirp Hlist
          let r [reward] of patch-ahead 1
          set r-episode lput r r-episode

          ;-- Q-learning update function
          let QQnew max [Qlist] of patch-ahead 1
          set Qnew Qnew + step-size * (r + discount * QQnew - Qnew) ;--perform Q-Learning
          set Qnew precision Qnew 3
          set Qlist replace-item dirp Qlist Qnew

          move-to patch-ahead 1

          if ticks = (num-episodes) [
            set process lput patch-here process
          ]
        ]
      ]

      let lng length r-episode
      let lngsum sum r-episode
      set ave-reward lngsum / lng
      set-current-plot "Average Reward Per Episode"
      plot ave-reward

      tick
    ]

    ;; best process
    let p [process] of one-of cars

    if length bestProcess = 0 [ set bestProcess p ]

    if length p < (length bestProcess) [ set bestProcess p ]

    if length bestProcess = length p [
      ; select more straight process (the one with less turns)
      if count-diagonals p < count-diagonals bestProcess [
        set bestProcess p
      ]
    ]

    ;; prepare for the next run
    init-run
    set num-run num-run + 1

    reset-ticks
  ]
end

; count occurrences of turns in a process
to-report count-diagonals[p]
  let c 0
  let i 0
  foreach p [
    x ->
    if x != last bestProcess [
      let next-el item (i + 1) bestProcess
      if [pxcor] of x != [pxcor] of next-el [ set c c + 1 ]
      if [pycor] of x != [pycor] of next-el [ set c c + 1 ]
    ]
    set i i + 1
  ]
  report c
end

to vis-best
  ask patches [set pcolor 9]
  ask patches with [pxcor = max-pxcor or pxcor = (- max-pxcor) or pycor = max-pycor  or pycor = (- max-pycor)][set pcolor 8]
  ask patch -4 4 [set pcolor green - 2] ;; set the green color of the starting point
  ask patch 4 -4 [set pcolor green]

  ask one-of cars [
    setxy -4 4
    foreach bestProcess
    [ x ->
      move-to x
      wait 0.5
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
658
459
-1
-1
40.0
1
10
1
1
1
0
0
0
1
-5
5
-5
5
0
0
1
ticks
20.0

SLIDER
8
153
201
186
num-episodes
num-episodes
0
10000
3000.0
10
1
NIL
HORIZONTAL

SLIDER
8
188
201
221
step-size
step-size
0.1
1
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
8
223
201
256
discount
discount
0
1
0.5
0.1
1
NIL
HORIZONTAL

BUTTON
142
41
206
106
SETUP
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
18
317
80
376
GO
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
665
40
1140
335
Average Reward Per Episode
episode
reward
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -15582384 true "" "plot count turtles"

SWITCH
9
74
140
107
view-rewards?
view-rewards?
1
1
-1000

MONITOR
89
346
191
391
n. of episode
ticks
1
1
11

SLIDER
8
258
201
291
num-runs
num-runs
1
100
40.0
1
1
NIL
HORIZONTAL

MONITOR
89
301
191
346
NIL
num-run
17
1
11

BUTTON
18
401
190
449
VIEW BEST ROUTE
vis-best
NIL
1
T
OBSERVER
NIL
V
NIL
NIL
1

SLIDER
9
40
140
73
n-obstacles-rate
n-obstacles-rate
0
4
4.0
1
1
NIL
HORIZONTAL

TEXTBOX
23
19
173
38
Setup options
15
0.0
1

TEXTBOX
23
133
131
151
Setup RL
15
0.0
1

@#$#@#$#@
## WHAT IS IT?

A demo example of a model for understanding reinforcement learning, with a car agent that must learn a path to a goal while avoiding obstacles.

## HOW IT WORKS

In the Interface, the "Setup options" section describes the parameters of the world

The "Setup RL" section describes the parameters of the RL model.

## HOW TO USE IT

Press SETUP to set the parameters of interest 
Press GO to run the learning phase
Press View the best route to see the learned path!

## THINGS TO NOTICE

Decrease the speed to notice the first errors of the machine agent, which slowly learns the right path.

## THINGS TO TRY

Try different configurations of Q-learning parameters.

## RELATED MODELS

This model extends with movements in 8 directions the RL Maze model:
http://ccl.northwestern.edu/netlogo/models/community/Reinforcement%20Learning%20Maze

## CREDITS AND REFERENCES

ABBPS
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@

extensions [gis]

breed [ robots robot ]

patches-own[
  reward  Qlist  name  l  ;; Q-learning variables
  street?                 ;; true if the patch is part of a street.
]

globals [
  bestProcess
  bestProcesses
  num-run
  num-act
  map-scheme
  center-x
  center-y
  streets
]

robots-own [
  Qsa
  Hlist
  process
  search-for
  speed         ;; the speed of the turtle
  wait-time     ;; the amount of time since the last time a turtle has moved
  motion-time   ;; the amount of time with positive speed
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;    SETUP    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  set map-scheme gis:load-dataset "gis-to/file.shp"
  draw-gis
  display-streets-in-patches
  setup-frame
  reduce-streets
  exsetup
  reset-ticks
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;   GO   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go

  tick

  while [num-act < num-stops] [
    set bestProcess []
    set num-run 1

    while [num-run <= num-runs] [

      reset-ticks

      while [ticks <= num-episodes]
      [
        ask robots [

          set Qsa 0

          while [[reward] of patch-here = 0]
          [
            ;--better search maximun action
            let Qnew 1
            let Qmax 0
            let dirp 0

            let rand random-float 1
            ifelse rand <= exploration-%
            [
              ; move-at-random
              let dir one-of Hlist          ; pick random direction
              set dirp position dir Hlist   ; find dir's position in the Hlist array
              set heading item dirp Hlist   ; turn the head to the next direction

              while [[street?] of patch-ahead 1 != true][  ; when the patch ahead is a street...
                set dir one-of Hlist        ; ...continue to pick a random direction
                set dirp position dir Hlist ; find dir's position in the Hlist array
                set heading item dirp Hlist ; turn the head to the next direction
              ]
              set Qnew item dirp Qlist ; find the value in Qlist with the same position as in the Hlist
            ]
            [
              while [Qnew != Qmax]
              [
                let dir one-of Hlist ;neighbors4 with [pcolor = 39]; Hlist ;--pick random direction
                set dirp position dir Hlist ;--find dir's position in the Hlist array
                set heading item dirp Hlist

                while [[street?] of patch-ahead 1 != true][ ; when the patch ahead is a street...
                  set dir one-of Hlist        ;--pick random direction
                  set dirp position dir Hlist ;--find dir's position in the Hlist array
                  set heading item dirp Hlist ; turn the head to the next direction
                ]

                set Qmax max Qlist ;--get max from the Qlist values of the current patch
                set Qnew item dirp Qlist ;--find the value in Qlist with the same position as in the Hlist
              ]
            ]

            let r [reward] of patch-ahead 1

            ;-- Q-learning update function
            let QQnew max [Qlist] of patch-ahead 1
            set Qnew Qnew + 1 * (r + discount * QQnew - Qnew) ;--perform Q-Learning
            set Qnew precision Qnew 3
            set Qlist replace-item dirp Qlist Qnew

            move-to patch-ahead 1

            ;at the end of the number of episodes, update the 'process' list
            if ticks = (num-episodes) [
              set process lput patch-here process
            ]
          ]

          move-to item 0 process
        ]

        tick
      ]

      ;; best process
      let p [process] of one-of robots

      if length bestProcess = 0 or length bestProcess > length p [
        set bestProcess p
      ]

      init-run

      set num-run num-run + 1

      reset-ticks
    ]

    set bestProcesses lput bestProcess bestProcesses

    set num-act num-act + 1
    ask one-of robots [ move-to item (length bestProcess - 1) bestProcess ]
    if num-act < num-stops [ init-run ]
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;   SETUP PROCEDURES   ;;;;;;;;;;;;;;;;;;;;;;;;

to draw-gis
  clear-drawing
  setup-world-envelope
  gis:set-drawing-color gray + 1
  gis:draw map-scheme 1
end

to setup-world-envelope
  gis:set-world-envelope gis:envelope-of map-scheme
  let world gis:world-envelope
  let x0 (item 0 world + item 1 world) / 2  + center-x
  let y0 (item 2 world + item 3 world) / 2  + center-y
  let W0 0.1 * (item 1 world - item 0 world) / 8
  let H0 0.1 * (item 3 world - item 2 world) / 8
  set world (list (x0 - W0) (x0 + W0) (y0 - H0) (y0 + H0))
  gis:set-world-envelope world
end

to display-streets-in-patches
  ask patches [ set pcolor black
                set street? true ]
  ask patches gis:intersecting map-scheme
   [ set pcolor white
     set street? false
   ]
  set streets patches with [street? = true]
end

to setup-frame
  ask patches with [pxcor = min-pxcor or pxcor = max-pxcor][ set pcolor blue set street? false ]
  ask patches with [pycor = min-pycor or pycor = max-pycor][ set pcolor blue set street? false ]
end

to reduce-streets   ; a draw procedure
  ask patches with [street?
    and
    length (filter [ i -> i = true ] [street?] of neighbors) = 8 ] [
    set street? false
  ]
end

to exsetup
  ;starting point
  let startx -12
  let starty 4

  ask patch startx starty [set pcolor  green - 2]

  import-process-info

  set bestProcess []
  set bestProcesses []

  create-robots 1
  [
    set shape "robot" set color 44 setxy startx starty set size 2 set Hlist [45 90 135 180 225 270 315 0]  ;; shape "person doctor" set color pink
    set search-for [ "A" "B" "C" "D" "E" ]
  ]

  init-run

  set num-act 0

  reset-ticks
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-geo
  ask patches [ set pcolor 9]

  ;import GIS shapefile
  set map-scheme gis:load-dataset "gis-to/file.shp"
  gis:set-drawing-color white
  gis:draw map-scheme 1
  gis:apply-coverage map-scheme "TIPO_AREA" l

  ;let's color different elements of the map
  ask patches with [l = "fiumi"] [set pcolor blue]
  ask patches with [l = "aree verdi"] [set pcolor 63]
  ask patches with [l = "isolati"] [set pcolor gray]
end


to setup-ground
  let x max-pxcor
  let y max-pycor

  ask patches with [pxcor = x or pxcor = (- x) or pycor = y or pycor = (- y)][set pcolor blue]
end

to import-process-info
  let i 0
  let activities ["A" "B" "C" "D" "E"]
  while [i < num-stops] [
    ask one-of patches with [pxcor > min-pxcor + 8 and pxcor < max-pxcor - 9 and pycor > min-pxcor + 8 and pycor < max-pycor - 9 and street? = true][
      set name item i activities
     ]
    set i i + 1
  ]
end

to init-run
  setup-rewards
  ;--initailize Q(s,a) values for the patches
  ask patches [set Qlist [0 0 0 0 0 0 0 0]] ;--this list stores the reward values of the state-action mapping
  ;--intialize cars
  ask one-of robots
  [ ; itialise the route of the turtle
    set process []
    set process lput patch-here process
  ]
end

to set-start
  let s item num-act [search-for] of one-of robots
  ask one-of patches with [name = s] [ set pcolor green set reward 10 ]
end

to setup-rewards
  ask patches [ ifelse pcolor > 60 [set reward -10][set reward 0] ]
  set-start
  ask patches [if name != 0 [set plabel name set plabel-color blue]]
end

to vis-best
  ask one-of robots [
    foreach bestProcesses
    [ b ->
      if length b > 0 [
          move-to item 0 b
          wait 0.4
          foreach b
          [ x ->
            move-to x
            wait 0.2
        ]
      ]
    ]
  ]
end

to center-here
  while [not mouse-down?] [wait .01]
  set center-x center-x + (mouse-xcor * gis-patch-size)
  set center-y center-y + (mouse-ycor * gis-patch-size)
  draw-gis
end

to-report gis-patch-size ;; note: assume width & height same
  let world gis:world-envelope
  report (item 1 world - item 0 world) / (max-pxcor - min-pxcor)
end


to Beautify
  ; apply GIS on patches
  gis:apply-coverage map-scheme "TIPO_AREA" l

  ;some house
  ask patches with [l = "isolati"][if random 10 <= 1 [ sprout 1 [set shape "house" set size 2 + random 1 set color 4 + random 5]] ]

  ;some trees
  ask patches with [l = "isolati"][if random 1000 <= 3  [ sprout 1 [set shape "tree" set size 2 + random 2 set color 63 + random 5]] ]

  ;create a red house for each step
  ask patches with [name != 0] [sprout 1 [ set shape "house" set size 3 set color red] ]

  ask patches [set pcolor white]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
786
587
-1
-1
8.0
1
25
1
1
1
0
0
0
1
-35
35
-35
35
0
0
1
ticks
30.0

SLIDER
16
271
188
304
num-episodes
num-episodes
1
1000
345.0
1
1
NIL
HORIZONTAL

SLIDER
16
339
188
372
exploration-%
exploration-%
0
0.1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
16
305
188
338
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
114
70
189
118
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
95
425
173
475
GO
go
NIL
1
T
OBSERVER
NIL
G
NIL
NIL
1

MONITOR
17
486
96
531
n. episode:
ticks
1
1
11

SLIDER
16
381
188
414
num-runs
num-runs
1
20
10.0
1
1
NIL
HORIZONTAL

MONITOR
150
486
202
531
n. run:
num-run
17
1
11

BUTTON
14
540
203
583
VIEW THE BEST ROUTE
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
16
30
189
63
num-stops
num-stops
1
5
3.0
1
1
NIL
HORIZONTAL

MONITOR
97
486
149
531
n. act:
num-act + 1
17
1
11

BUTTON
97
139
188
173
more houses
ask patches with [l = \"isolati\"][if random 10 = 1 [ sprout 1 [set shape \"house\" set size 2 + random 1 set color 4 + random 5]] ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
133
213
188
247
red track
ask patches with [street?] [set pcolor red]\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
78
213
133
247
all white
ask patches [set pcolor white]\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
14
123
144
141
The environment:
13
0.0
1

BUTTON
25
153
85
187
NIL
Beautify
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
97
174
188
207
more trees
ask patches with [l = \"isolati\"][if random 10 = 1 [ sprout 1 [set shape \"tree\" set color 63 + random 6 set size 1 + random 2 ]] ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
19
252
169
270
RL setup:
14
0.0
1

TEXTBOX
15
83
107
101
Initial setup:
14
0.0
1

TEXTBOX
16
12
166
30
Number of activities
14
0.0
1

TEXTBOX
21
442
83
476
RL run:
14
0.0
1

TEXTBOX
19
218
73
236
Options:
13
0.0
1

@#$#@#$#@
## WHAT IS IT?

A RL demo model to describe how to address a self-driving healthcare robot in a GIS-based map (e.g., a robot for drug delivery in a city).

## HOW IT WORKS

Setup button creates the environment (based on GIS map) with up to 5 stops (num-stops) to reach, e.g. the places to be served by the robot.

Some optional procedures improve the visualisation ('beautify' the environment with houses and trees, displays in red the path that the robot can take).

Press Go button to apply RL. The robot start learning the best route to the activities (consider to unckeck "Viev updates" to have a faster solution). 
Depending on computational capabilities, the learning process takes some minutes.

Finally, press the button "Visualise the best route" to visualise the learned solution.

## HOW TO USE IT

Setup the simulation with random location for activities.

## THINGS TO NOTICE

The robot moves in 8 directions: UP, UP-RIGHT, RIGHT, DOWN-RIGHT, DOWN, DOWN-LEFT, LEFT, UP-LEFT. 

## THINGS TO TRY

Try to decrease/increase the number of episodes or the % of exploration to check the impact on the learning process.

## EXTENDING THE MODEL

1- add performance  metrics to each route (e.g., with a cost for each path)
2- upload one or more  sequence of activities from real data (event log)
3- use another GIS with streets of interest

## RELATED MODELS

This model extends with movements in 8 directions the RL Maze model:
http://ccl.northwestern.edu/netlogo/models/community/Reinforcement%20Learning%20Maze

## CREDITS AND REFERENCES

Emilio Sulis, Kuldar Taverer
Agent-based business process simulation
Springer 2020
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

person doctor
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -13345367 true false 135 90 150 105 135 135 150 150 165 135 150 105 165 90
Polygon -7500403 true true 105 90 60 195 90 210 135 105
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -1 true false 105 90 60 195 90 210 114 156 120 195 90 270 210 270 180 195 186 155 210 210 240 195 195 90 165 90 150 150 135 90
Line -16777216 false 150 148 150 270
Line -16777216 false 196 90 151 149
Line -16777216 false 104 90 149 149
Circle -1 true false 180 0 30
Line -16777216 false 180 15 120 15
Line -16777216 false 150 195 165 195
Line -16777216 false 150 240 165 240
Line -16777216 false 150 150 165 150

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

robot
false
4
Rectangle -7500403 true false 45 60 255 202
Rectangle -1184463 true true 60 90 240 165
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 210 75 210 105 165 105 165 75
Circle -16777216 true false 204 174 42
Rectangle -7500403 true false 106 35 195 45
Circle -16777216 true false 129 174 42
Circle -16777216 true false 54 174 42
Circle -7500403 false false 54 174 42
Circle -7500403 false false 129 174 42
Circle -7500403 false false 204 174 42
Polygon -16777216 true false 135 75 135 105 90 105 90 75
Rectangle -955883 true false 75 45 225 60
Rectangle -955883 false false 60 75 240 165

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

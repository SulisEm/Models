breed [wumpuss wumpus]
breed [miners miner]

breed [breezes breeze]
breed [pits pit]
breed [golds gold]
breed [stenches stench]

breed [arrows arrow]

patches-own [
  free?
]

wumpuss-own [
 is-dead?
]

miners-own [
 list-sensors
 #arrow
 hold-gold?
 update-sensors?
 can-grab?
 ]

globals [
  monitor-points
  monitor-arrow
  monitor-direction

  check-start
  exit-game?     ; check the final  condition

  update-view?
]

;;;;;;;;;;;;;;;;;;;;;;;       SETUP       ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  ca
  setup-background
  setup-miner
  setup-wumpus
  setup-gold
  setup-pit

  setup-monitors
  setup-var
  reset-ticks
end

;;;;;;;;;;;;;;;;;;;;;;;        GO       ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go

  if check-start = False [set check-start True]
  if check-start [
    if using-mouse? [ check-mouse ]

    check-update-view

    check-wumpus-here   ; stop condition: the wumpus kills the miner
    check-pits-here     ; stop condition: the miner falls down into a pit
    check-exit-cave     ; stop condition: the miner exits the cave

    if exit-game? [ stop ]

    ask miner 0 [
      if update-sensors? [
        miner-sensoring ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;  Setup procedures  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-background
  ask patches [
    ifelse (pxcor mod 2 = 0 and pycor mod 2 != 0) or (pxcor mod 2 != 0 and pycor mod 2 = 0)
     [ set pcolor 9.5 ][ set pcolor 49.5 ]

    set free? true

  ]
  ask patch 1 0 [set free? false]
  ask patch 0 1 [set free? false]
end

to setup-miner
  create-miners 1 [
    set color orange
    set size 0.5
    set heading 90

    set can-grab? false

    ask patch-here [set free? false]

    set list-sensors [ "None" "None" "None" "None" "None" ]
    set update-sensors? true

    set #arrow 1
    set hold-gold? false
  ]
end

to setup-wumpus
  ask one-of patches with [free?][
    sprout-wumpuss 1 [
      set color gray set size 0.6 set shape "wumpus"
      set size 0.0001
      set is-dead? false
      ask neighbors4 [ sprout-stenches 1 [set shape "stench-wumpus" set size 0.0001 ] ]
    ]
    set free? false
  ]
end

to setup-gold
  ask one-of patches with [free?][
    sprout-golds 1 [
      set shape "gold"
      set size 0.0001
    ]
    set free? false
  ]
end

to setup-pit
  ask patches with [free?] [
    let prob random 100
    if prob < 20 [
      sprout-pits 1 [
        set color gray set size 0.8 set shape "circle" ;
        set size 0.0001
        ask neighbors4 [
            sprout-breezes 1 [set shape "breeze-pit" set size 0.0001] ]
      ]
      set free? false
    ]
  ]
end


to setup-monitors
   clear-output
   output-print " GRAB THE GOLD, COME BACK TO START POSITION AND CLIMB OUT OF THE CAVE!"
   output-print " PAY ATTENTION TO PITS AND WUMPUS!     *** press GO to start *** "
   set monitor-points 0
   set monitor-arrow 1
   set monitor-direction "RIGHT"
end

to setup-var
  set update-view? true
  set exit-game? false
  set check-start false
end

;;;;;;;;;;;;;;;;;;;;;;;;;  GO procedures  ;;;;;;;;;;;;;;;;;;;;;;


to check-update-view

  if update-view?
  [
    tick

    clear-output
    update-direction

    ask [patch-here] of miner 0 [

      ; checking for breeze pit
      if any? turtles-here with [shape = "breeze-pit"][
        ask turtles-here with [shape = "breeze-pit"][
          set size 1
        ]
      ]

      ; checking for stench wumpus
      if any? turtles-here with [shape = "stench-wumpus"][
        ask turtles-here with [shape = "stench-wumpus"][
          set size 1
        ]
      ]

      ; checking for gold
      if any? golds-here [
        ask golds-here [
          set size 0.9
        ]
      ]
    ]
    set update-view? false
  ]
end

to check-wumpus-here
  if any? wumpuss-on [ patch-here ] of one-of miners [
    set monitor-points monitor-points - 1000
    clear-output output-print " * EATEN BY WUMPUS :-( * GAME OVER *"
    show-all
    set exit-game? True
  ]
end

to check-pits-here
  if any? pits-on [ patch-here ] of one-of miners [
    set monitor-points monitor-points - 1000
    clear-output output-print " * YOU FELL INTO A PIT :-( * GAME OVER * "
    show-all
    set exit-game? True
  ]
end

to check-exit-cave
  if exit-game? [
    if any? miners with [hold-gold?] and any? miners-on patch 0 0 [
      clear-output output-print " ***  WELL DONE !!!  *** "
      output-print (word "Game completed in " (ticks - 1) " steps, with a score of " monitor-points "!" )
      set exit-game? True
    ]
  ]
end

to check-mouse
  ;check direction
  ifelse  abs (mouse-ycor - [ycor] of miner 0) > abs  (mouse-xcor - [xcor] of miner 0)
  [ ; set y coordinate
    ifelse mouse-ycor > [ycor] of miner 0 [ask miner 0 [set heading 0]][ask miner 0 [set heading 180  ]]
    update-direction
  ]
  [ ; set x coordinate
    ifelse mouse-xcor > [xcor] of miner 0 [ask miner 0 [set heading 90]][ask miner 0 [set heading 270  ]]
    update-direction
  ]

  ;check click
  if mouse-down? and member? (patch mouse-xcor mouse-ycor) [neighbors4] of one-of miners
   [
      ask miner 0 [ move-to  patch mouse-xcor mouse-ycor
        set update-sensors? true
        if not can-grab? and any? golds-here[
        set can-grab? true
        ]
        wait 0.5
      ]
      set monitor-points monitor-points - 1
      set update-view? true
  ]

  if mouse-down? and (patch mouse-xcor mouse-ycor) = [patch-here] of miner 0[
    ask miner 0 [
      if any? golds-on patch-here and can-grab? [
        grab-miner
      ]
       if patch-here = patch 0 0 [set exit-game? true]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;    ACTUATORS    ;;;;;;;;;;;;;;;;;;;;;;;
to fd-1
  if check-start [
    ask miner 0 [fd 1 set update-sensors? true ]
    set monitor-points monitor-points - 1
    set update-view? true
  ]
end

to rt-dx
  if check-start [
    ask miner 0 [rt 90 set update-sensors? true ]
    update-direction
  ]
end

to rt-sx
  if check-start [
    ask miner 0 [rt -90 set update-sensors? true ]
    update-direction
  ]
end

to grab-miner
  ask miners [
    if any? golds-here [
      ask golds-on patch-here [die]
      set monitor-points monitor-points + 1000
      set hold-gold? true
      set update-sensors? true
    ]
  ]
end

to shoot
  if check-start [
    ask one-of miners [
      ifelse monitor-arrow > 0 [
        hatch-arrows 1 [
          set shape "wumpus-arrow"
          set size 0.8
          set color 3
          set monitor-arrow monitor-arrow - 1
          throw-arrow
        ]
        set update-sensors? true
        set monitor-points monitor-points - 10
      ]
      [
        output-print " * No more arrows! :-( * "
        wait 2
        clear-output
      ]
    ]
  ]
end

to throw-arrow
  ifelse any? wumpuss-on patch-ahead 0.1 [
    set monitor-points monitor-points + 1000
    kill-wumpus
    die
  ]
  [
    ifelse patch-ahead 0.2 = nobody
    [ die ]
    [ fd 0.1 wait 0.1 throw-arrow ]
  ]
end

to kill-wumpus
  ask wumpuss-on patch-ahead 0.1 [
    set is-dead? true
    let pc pcolor set pcolor orange
    set size 0.8
    output-print " - you killed the Wumpus! -"
    wait 2
    clear-output
    set pcolor (pc - 1)
    die
  ]
end

to miner-sensoring
  perceive-stench
  perceive-breeze
  perceive-glitter
  perceive-wall
  perceive-scream

  set update-sensors? false
end

to perceive-stench
  ifelse any? stenches-here
  [ set list-sensors replace-item 0 list-sensors "Stench" ]
  [ set list-sensors replace-item 0 list-sensors "None" ]

end

to perceive-breeze
  ifelse any? breezes-here
  [ set list-sensors replace-item 1 list-sensors "Breeze" ]
  [ set list-sensors replace-item 1 list-sensors "None" ]
end

to perceive-glitter
  ifelse any? golds-here
  [ set list-sensors replace-item 2 list-sensors "Glitter" ]
  [ set list-sensors replace-item 2 list-sensors "None" ]
end

to perceive-wall
  ifelse patch-ahead 0.6 = nobody
  [ set list-sensors replace-item 3 list-sensors "Bump" ]
  [ set list-sensors replace-item 3 list-sensors "None" ]
end

to perceive-scream
  ifelse any? wumpuss with [is-dead? = true] or not any? wumpuss
  [ set list-sensors replace-item 4 list-sensors "Scream" ]
  [ set list-sensors replace-item 4 list-sensors "None" ]
end

to show-all
  ask wumpuss [set size 1 ]
  ask golds [set size 0.9]
  ask pits [set size 0.8]
end

to update-direction
  if [heading] of miner 0 = 90 [ set monitor-direction "RIGHT"]
  if [heading] of miner 0 = 180 [ set monitor-direction "DOWN"]
  if [heading] of miner 0 = 270 [ set monitor-direction "LEFT"]
  if [heading] of miner 0 = 0 [ set monitor-direction "UP"]
  ask miner 0 [ set update-sensors? true ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
376
75
784
484
-1
-1
100.0
1
20
1
1
1
0
0
0
1
0
3
0
3
0
0
1
ticks
30.0

BUTTON
63
91
118
145
SETUP
setup
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
22
36
187
57
WUMPUS WORLD
18
72.0
1

MONITOR
223
181
283
226
#Arrow
monitor-arrow
17
1
11

BUTTON
168
378
235
426
RIGHT
;if not using-mouse? [\nrt-dx\n;]
NIL
1
T
OBSERVER
NIL
M
NIL
NIL
1

BUTTON
97
378
165
426
LEFT
;if not using-mouse? [\nrt-sx\n;]
NIL
1
T
OBSERVER
NIL
N
NIL
NIL
1

BUTTON
109
432
164
484
FWD 1
if not using-mouse? [fd-1]
NIL
1
T
OBSERVER
NIL
I
NIL
NIL
1

BUTTON
287
173
359
226
SHOOT!
shoot
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

MONITOR
790
228
871
273
Points
monitor-points
17
1
11

BUTTON
261
383
352
424
Grabbing
if not using-mouse? [grab-miner]\n
NIL
1
T
OBSERVER
NIL
G
NIL
NIL
1

BUTTON
304
90
359
144
GO
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

OUTPUT
200
21
870
70
14

MONITOR
873
228
976
273
ACTIONS TAKEN
ticks - 1
0
1
11

BUTTON
841
451
918
484
NIL
show-all
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
15
161
155
179
MOVE THE AGENT 
15
22.0
1

TEXTBOX
31
381
100
416
Rotate on the:
15
22.0
1

TEXTBOX
24
447
133
466
Forward 1 room
15
22.0
1

TEXTBOX
219
160
294
179
Shooting
15
102.0
1

TEXTBOX
257
362
356
381
Grab the gold
15
12.0
1

BUTTON
192
451
353
484
CLIMB OUT OF THE CAVE
if not using-mouse? [set exit-game? true]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
870
104
974
149
DIRECTION
monitor-direction
0
1
11

TEXTBOX
798
110
888
147
Actual direction:
15
102.0
1

TEXTBOX
798
209
884
227
Monitors:
15
102.0
1

TEXTBOX
159
108
300
129
Press GO to start:
16
72.0
1

TEXTBOX
15
107
70
131
New game:
16
72.0
1

SWITCH
15
230
177
263
USING-MOUSE?
USING-MOUSE?
0
1
-1000

TEXTBOX
210
430
341
449
End of the game?
15
12.0
1

TEXTBOX
17
296
345
329
Mouse: CLICK to move, grab the gold, exit\nTo shoot: check the direction, then press S 
12
1.0
1

TEXTBOX
18
335
243
366
Keyboard: press the following buttons/commands:
12
1.0
1

TEXTBOX
16
209
205
228
Select keyboard or mouse
14
1.0
1

TEXTBOX
17
269
117
287
INSTRUCTIONS:
14
130.0
1

TEXTBOX
849
432
938
450
Solutions:
13
2.0
1

MONITOR
790
362
975
407
NIL
[list-sensors] of miner 0
17
1
11

TEXTBOX
791
341
941
359
Sensors-of-miner:
13
0.0
1

@#$#@#$#@
## WHAT IS IT?

The classic Wumpus World game from Michael Genesereth as mentioned in Russell-Norvig "Artificial Intelligence. A modern approach" as an excellent environment for testing intelligent agents.


PEAS Description:

(P)erformance: 
-1 for each action taken; 
-10 for using the arrow; 
+1000 for picking up the gold;
-1000 for falling into a pit or being eaten by the wumpus.

(E)nvironment: 
- The agent always starts in the botton-right square facing to the right. [setup-miner procedure]
- The location of the Gold and the Wumpus are chosen randomly (from the squares other than the start square). [setup-wumpus and setup-gold]
- Each square other than the start can be a pit with probability 0.2  [ setup-pit ]

(A)ctuators: 
- The agent can move forward [fd-1], turn left by 90° [rt-sx], turn right by 90° [rt-dx] 
- The action Grab can be used to pick up an object that is in the same square as the agent. [grab-miner procedure]
- The action Shoot be used to fire an arrow in a straight line in the direction the agent is facing. [shoot]
- The arrow continues until it either hits (and hence kills) the wumpus or hits a wall. The agent only has one arrow, so only the first Shoot action has any effect [throw-arrow]

(S)ensors: 
Sensors: The agent has five sensors, each of which gives a single bit of information:

- In the square containing the wumpus and in the directly (not diagonally) adjacent
squares the agent will perceive a stench. 
- In the squares directly adjacent to a pit, the agent will perceive a breeze. 
- In the square where the gold is, the agent will perceive a glitter. 
- When an agent walks into a wall, it will perceive a bump. 
- When the wumpus is killed, it emits a woeful scream that can be perceived anywhere in the cave.


## HOW IT WORKS

The Wumpus goal is to grab the gold, get back to the lower-left square, and climb out of the cave. 
Move around using mouse or keyboards (turn left, turn right, and go forward buttons), accordingly to the choice in the "Using-mouse?" button.


## EXTENDING THE MODEL

1. A monitor/variable Record to register the best ever scores
2. A learning strategy for agent reinforcement, to automatically solve the game


## CREDITS AND REFERENCES

Emilio Sulis
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

arrow-bullet
true
0
Polygon -7500403 true true 150 0 75 150 105 150 120 285 180 285 195 150 225 150
Polygon -7500403 true true 135 15 105 45 75 150 60 255 225 150 195 45 165 15
Polygon -7500403 true true 75 240 75 240 60 255 240 255 225 150
Polygon -7500403 true true 75 255 105 270 195 270 225 255 75 255

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

breeze
false
0
Polygon -11221820 true false 150 210 90 225 30 195 75 240 135 225
Polygon -13791810 true false 150 210 210 225 255 195 210 240 165 225
Polygon -13791810 true false 150 180 135 180 45 135 90 180 135 195
Polygon -11221820 true false 150 165 165 180 210 180 255 120 195 165
Polygon -11221820 true false 150 120 90 105 45 60 75 105 135 135
Polygon -13791810 true false 150 105 180 120 225 105 255 60 195 105

breeze-pit
false
0
Polygon -11221820 true false 150 135 90 135 30 105 75 150 135 135
Polygon -13791810 true false 150 120 210 135 255 120 210 150 165 135
Polygon -13791810 true false 150 105 105 105 30 60 75 105 120 120
Polygon -11221820 true false 150 90 165 105 195 105 255 75 195 90
Polygon -11221820 true false 150 75 90 60 45 15 75 60 135 90
Polygon -13791810 true false 150 60 180 75 225 60 255 15 195 60

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

gold
false
3
Polygon -7500403 true false 210 285 285 225 285 135 210 195
Polygon -1184463 true false 210 195 75 150 150 120 285 135
Polygon -1184463 true false 75 150 75 225 210 285 210 195
Line -1184463 false 210 285 210 195
Line -7500403 false 255 210 75 150
Line -1184463 false 210 195 285 135

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

smell
true
0

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

stench
false
0
Rectangle -6459832 true false 75 255 240 270
Line -6459832 false 45 45 105 240
Line -6459832 false 90 135 60 15
Line -6459832 false 120 210 105 75
Line -6459832 false 150 150 120 15
Line -6459832 false 210 60 210 15
Line -6459832 false 90 60 90 15
Line -6459832 false 255 45 210 240
Line -6459832 false 240 15 210 135
Line -6459832 false 195 15 165 150
Line -6459832 false 195 75 195 210
Line -6459832 false 180 150 165 240
Line -6459832 false 135 150 150 240

stench-wumpus
false
0
Rectangle -6459832 true false 75 255 225 270
Line -6459832 false 60 195 90 240
Line -6459832 false 120 240 60 165
Line -6459832 false 120 210 105 120
Line -6459832 false 180 180 195 135
Line -6459832 false 90 180 75 135
Line -6459832 false 240 210 210 240
Line -6459832 false 225 120 195 240
Line -6459832 false 180 105 165 195
Line -6459832 false 180 195 180 225
Line -6459832 false 135 195 150 240
Line -6459832 false 135 120 150 180
Line -6459832 false 210 225 255 150

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

wumpus
false
0
Circle -8630108 true false 30 15 240
Circle -16777216 true false 59 44 182
Rectangle -16777216 true false 45 135 255 270
Polygon -8630108 true false 45 150
Polygon -8630108 true false 30 120 30 120 15 270 45 270 60 120 75 120
Polygon -8630108 true false 255 270 285 270 270 120 240 120
Circle -8630108 true false 84 114 42
Circle -8630108 true false 174 114 42
Polygon -16777216 true false 90 105 90 105 150 150 210 105

wumpus-arrow
true
0
Polygon -7500403 true true 150 15 120 75 120 75 150 60 180 75 150 15
Rectangle -7500403 true true 225 45 225 270
Polygon -7500403 true true 150 30 135 255 150 240 165 255 150 30

wumpus-breeze
false
0
Circle -13345367 false false 15 15 30
Circle -13345367 false false 41 16 30
Circle -13345367 false false 67 15 30
Rectangle -1 true false 15 10 105 30

wumpus-gold
false
3
Polygon -7500403 true false 210 285 285 225 285 75 210 135
Polygon -1184463 true false 210 135 15 75 105 45 285 75
Polygon -1184463 true false 15 75 15 210 210 285 210 135
Line -16777216 false 210 285 210 135
Line -16777216 false 210 135 15 75
Line -16777216 false 210 135 285 75

wumpus-stench
false
0
Rectangle -6459832 true false 225 45 270 60
Line -6459832 false 210 15 225 45
Line -6459832 false 225 30 225 15
Line -6459832 false 240 45 240 15
Line -6459832 false 255 45 255 30
Line -6459832 false 270 45 285 15
Line -6459832 false 270 30 270 15

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

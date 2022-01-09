;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Business Process Analysis - Introductory Example ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [ workers worker ]    ; Agents working in the system
breed [ entities entity ]   ; Entities (e.g. orders) arriving into the system

patches-own [       ; Define the variables of all patches (activities)
  name              ; Name of the activity
  service-duration  ; Duration time (average) of the activity
]

entities-own [      ; Define the variables belonging to each entity
   entity-service?  ; Is having a service?
   CT-begin         ; Record the starting time of a Cycle-Time
]

workers-own [       ; define the variables belonging to each worker
  is-working?       ; a worker is working
  working-with      ; the entity with which it is serving
  w-time-end-act    ; the end of the working time on a task

  time-working    ; monitoring working time
  time-waiting    ; monitoring waiting time
]

globals [ ; define global variables
  list-entities   ; list of entities entering into the system
  list-cycle-time ; contains the list of all cycle-time, updated before an entity exits the process

  monit-entities  ; monitor for entities
  monit-exit      ; monitor of processed entities
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;            SETUP              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  ca               ; clear-all
  setup-variables  ; initialize main variables
  setup-space      ; create the environment/process
  setup-workers    ; initialize the agents
  reset-ticks      ; reset tick before to start
end

to setup-variables          ; setup main cycle programming variables
  set monit-entities 0      ; initialize the monitor of entities to 0
  set list-entities []      ; initialize the (empty) list containing all entities
  set list-cycle-time []    ; initialize the (empty) list of kpis

  set-default-shape entities "dot"   ; the shape of entities
  set-default-shape workers "person" ; the shape of workers
  reset-ticks
end

to setup-space
  ask patches [ set pcolor 9.9]  ; set the background-color to white

  ask patches with [ pxcor = -14 and pycor = 0 ] [ set name "start" set pcolor 6]  ; set the initial patch
  ask patches with [ pxcor > -12 and pxcor < -6 and pycor > -2 and pycor < 2  ] [ set pcolor 107 set name "A" set service-duration 3 ] ; task A
  ask patches with [ pxcor > -3  and pxcor < 3  and pycor > 2  and pycor < 6  ] [ set pcolor 107 set name "B" set service-duration 2 ] ; task B
  ask patches with [ pxcor > -7  and pxcor < -1 and pycor > -6 and pycor < -2 ] [ set pcolor 107 set name "C" set service-duration 4 ] ; task C
  ask patches with [ pxcor > 1   and pxcor < 7  and pycor > -6 and pycor < -2 ] [ set pcolor 107 set name "D" set service-duration 5 ] ; task D
  ask patches with [ pxcor > 6   and pxcor < 12 and pycor > -2 and pycor < 2  ] [ set pcolor 107 set name "E" set service-duration 6 ] ; task E
  ask patches with [ pxcor = 14  and pycor = 0 ] [ set pcolor 6 set service-duration 0 set name "end" ]                               ; patch with the conclusion of the process

  if labels? [
    ask patch -9 2  [set plabel "A" set plabel-color black]
    ask patch  0 6  [set plabel "B" set plabel-color black]
    ask patch -4 -6 [set plabel "C" set plabel-color black]
    ask patch  3 -6 [set plabel "D" set plabel-color black]
    ask patch  9 2  [set plabel "E" set plabel-color black]
  ]
end

to setup-workers  ; create workers and insert into specific lists (i.e. list-workers)
  create-workers num-workers [
    setxy 11 9 set color lime ; initial position and color
    set is-working? False     ; workers are not actives
    set time-working 0      ; monitoring working time
    set time-waiting 0      ; monitoring waiting time
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;         E X E C U T I O N           ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go    ; main cycle
  tick   ; increment (ticks) one unit of time

  new-arrival            ; introduce new entities
  workers-check-entities ; workers check for new entities
  check-time             ; check the concluding time of tasks
  monitoring-stats       ; update monitor stats

  if monit-entities = n-entities  [ stop ] ; the stop condition
end

to new-arrival
  if random freqArrival = 0 [ ; with a probability of 1 / freqArrival (every time unit)
    create-entities 1 [       ; create a new entity
      set monit-entities monit-entities + 1           ; increment the monitori of entities
      set list-entities lput self list-entities       ; add the new arrived entity to the queue (list of entities)
      move-to one-of patches with [ name = "start" ]  ; positioning the entity in the patch named "start"
      set size 1.5 set color 21                       ; set initial size and color
      if traces? [ pd ]                               ; keep trace of movements?
      set CT-begin ticks                              ; set the initial value of Cycle-Time
      set entity-service? False                       ; any service at the start
    ]
  ]
end

to-report compute-next-task [n]  ;eturn the next task acording to the flow
  if n = "start" [ report "A" ]
  if n = "A" [ ifelse random 100 < perc-gateway [ report "B" ][ report "C" ] ]
  if n = "C" [ report "D" ]
  if n = "D" [ report "E" ]
  if n = "B" [ report "E" ]
  if n = "E" [ report "end" ]
end

to workers-check-entities
  if any? workers with [not is-working?] [  ; free workers start
    if not empty? list-entities
    [
      let ord first list-entities                     ; remove first entity from list
      set list-entities but-first list-entities       ;

      ask ord [                                       ; the entity moves to the next patch/task
        let nt compute-next-task [name] of patch-here ;
        move-to one-of patches with [ name = nt ]     ;
        set entity-service? true                      ; start the service
      ]

      ask one-of workers with [not is-working?][      ; the worker move to work on the selected entity
        move-to ord
        set working-with ord
        set is-working? true
        set w-time-end-act ticks + [service-duration] of patch-here ; compute the duration of the service
      ]
    ]
  ]
end

to check-time
  ask workers with [ is-working? and ticks = w-time-end-act] [ ; check the conclusion of a service
    set is-working? False
    ask working-with [                               ; manage the corresponding order/entity
      ifelse [name] of patch-here = "E" [            ; check: is it the last task?
        move-to one-of patches with [ name = "end" ] ; move: to last patch/task
        update-final                                 ; update monitors
        die
      ]
      [
        set entity-service? false                   ; set entity as free and insert into queue
        set list-entities lput self list-entities   ;
      ]
    ]
    move-to patch 0 0
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;          MONITOR AND KPIs           ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to monitoring-stats
    ask workers with [not is-working?] [
      set time-waiting time-waiting + 1]
    ask workers with [is-working?] [
      set time-working time-working + 1 ]
end

to update-final           ; update monitors/check final condition
  set monit-exit monit-exit + 1
  set list-cycle-time lput (ticks - CT-begin) list-cycle-time
end
@#$#@#$#@
GRAPHICS-WINDOW
192
15
632
299
-1
-1
13.1
1
20
1
1
1
0
1
1
1
-16
16
-10
10
0
0
1
ticks
30.0

BUTTON
40
14
96
48
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

BUTTON
97
14
154
49
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
1

MONITOR
895
16
966
61
Processed
monit-exit
1
1
11

SLIDER
6
105
189
138
n-entities
n-entities
1
500
300.0
1
1
NIL
HORIZONTAL

MONITOR
856
63
966
108
Avg. Cycle Time
sum (list-cycle-time) / monit-entities
1
1
11

MONITOR
829
16
893
61
Waiting
length (list-entities)
2
1
11

TEXTBOX
639
12
761
59
Performance measures
18
22.0
1

TEXTBOX
759
74
853
100
Cycle time
18
93.0
1

TEXTBOX
640
71
681
94
KPIs
18
102.0
1

TEXTBOX
640
108
728
156
Resource utilization
18
93.0
1

TEXTBOX
6
84
64
106
Orders
18
132.0
1

SLIDER
6
196
189
229
num-workers
num-workers
1
10
3.0
1
1
NIL
HORIZONTAL

TEXTBOX
6
175
73
197
Staff
18
113.0
1

TEXTBOX
5
230
79
252
Gateway
18
52.0
1

SLIDER
6
252
189
285
perc-gateway
perc-gateway
0
100
72.0
1
1
NIL
HORIZONTAL

PLOT
637
160
966
298
Resource utilization
NIL
NIL
0.0
0.0
0.0
0.0
true
true
"" ""
PENS
"Waiting Time" 1.0 0 -7171555 true "" "if ticks > 0 [plot mean [time-waiting] of workers / n-entities]"
"Working Time" 1.0 0 -14439633 true "" "if ticks > 0 [plot mean [time-working] of workers / n-entities]"

MONITOR
902
110
966
155
R.U. (%)
sum [time-working ] of workers /\n( sum [time-working ] of workers + sum [time-waiting ] of workers) * 100
1
1
11

SLIDER
6
140
189
173
freqArrival
freqArrival
1
10
5.0
1
1
NIL
HORIZONTAL

MONITOR
761
110
831
155
res-Work
sum [time-working ] of workers
17
1
11

MONITOR
832
110
901
155
res-Wait
sum [time-waiting ] of workers
1
1
11

MONITOR
761
16
827
61
#Entities
monit-entities
1
1
11

SWITCH
6
52
96
85
labels?
labels?
0
1
-1000

SWITCH
98
52
189
85
traces?
traces?
1
1
-1000

TEXTBOX
11
286
190
305
B <----------------->  C
12
0.0
1

@#$#@#$#@
## WHAT IS IT?

An introductory model of five activities (A to E) and one gateway (G1) corresponding to the following BPMN diagram:

![Example](file:ABBPS_Intro_Business_Process-BPMN.png)

This model can be the case of a small business process that concerns the execution of a certain number of production orders (entities arriving in the system) with a set of workers (staff). The orders can arrive (start) according to a certain temporal distribution, and managed by five different activities until their completion (end). The gateway G1 discriminates the flow between the two concurrent branches of activities B or (C and D).

## DURATION OF TASKS

The set of task names and their respctive duration is {A : 3, B : 3, C : 2, D : 4, E : 6}

Some indictors (KPIs) refer to process metrics (Cycle time, i.e. the average time of execution is the )
 and human resources utilization (staff)  - the amoubn ot time worked by all the staff members (). 

## HOW IT WORKS

New entities (e.g. orders) arrive into the system according to the frequency defined in the 'freqArrival' slider.

Workers free look for an order to work with from the queue of entities arrived into the system. They have two variables to record the time waiting and the time working.

## HOW TO USE IT

Modify the initial settings in the Interface tab to obtains different simulation results.

## THINGS TO TRY

Modify parameters to obtain a convenient waiting time (orders) or working time (staff).

Investigate the impact of the frequency arrival and the number of workers on performance measures/KPIs/Resource utilization. 

## CREDITS AND REFERENCES

Emilio Sulis
Agent-Based Business Process Simulation
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

breed [ patients patient ]

patches-own [
  name             ; name of patch: "REG", "WA"
  free?            ; true = free
  reg-queue        ; the queue of patients (a list)
]

patients-own [
  urgency-level     ; four not very urgent cases

  state             ; two states "waiting", "service"
  arrival-time      ; the arrival time (ticks)
  arr-time-in-queue ; the arrival time in queue (ticks)

  dest-place        ; the phisical place (patch) in the queue (view area)
  task-duration     ; the duration of the REG task

  cycle-time        ; the time from arrival to dismission at REG
  waiting-time      ; the time a patient waited from arrival to start
]

globals [
  simulation-stop

  ; monitors
  monitor-n-of-patients    ; number of patients
  monitor-p-served         ; number of patients served
  monitor-c-waiting        ; number of patients served
  ; KPIs
  monitor-avg-cycle-time   ; KPI: Avg time from start to exit (all patients)
  monitor-avg-wait-time    ; KPI: Avg time from arrival in waiting area to registration area (all patients)
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;                        SETUP                           ;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  ca
  setup-world
  setup-duration
  reset-ticks
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;                          GO                            ;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  tick                      ;; 1 tick = 1 second ;; 1 minute = 60 ticks ;; 60 minutes/1 hour = 3600 ticks
  arrival-new-patients      ;; procedure for new patients
  check-working             ;; if a REG area is free, the first in the queue moves to REG and the others advance in the queue
  if ticks = simulation-stop [ stop ] ;; stop condition
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;                SETUP procedures                        ;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-world
  ; initialize patches
  ask patches [ set name "" set free? True set pcolor 9.5 ]
  ask patches with [ pycor <=  6 and pycor >= -6 ] [
    ifelse pycor mod 3 = 0 [ set pcolor 9 ][ set pcolor 8 ]
  ]

  ; registration office
  ask patch 9 0 [
    set name "REG"     ; the registration office
    set reg-queue []   ; the queue of the reg. office
    set pcolor gray
  ]

  ; waiting area / hall
  ask patches with [ pxcor > -11 and pxcor < 5 and pycor > -5 and pycor < 5] [
    set name "WA"
    set pcolor 29.5
  ]

  ; the wall
  ask patches with [ pxcor = 9 and (pycor > 0 or pycor < 0) ]  [
      sprout 1 [
        set shape "square" set heading 270 set color 36
      ]
      set pcolor 37
    ]
  ask patches with [ pxcor > 9 ] [ set pcolor 9.1 ]
end

to setup-duration
  if Duration = "8 hours" [ set simulation-stop 28800]  ; 8 hours = 8h * 60 min * 60 secs
  if Duration = "1 day"   [ set simulation-stop 86400]  ; one day = (60 sec * 60 min * 24h) => 86400
  if Duration = "1 week"  [ set simulation-stop 604800] ; one week (7 days) = 604800 ticks (7 days * 24h * 60 min * 60 sec/ticks)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;                     GO procedures                          ;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to arrival-new-patients     ;; arrival of patients
  if random 3600 < avg-patients-1-hour [ setup-patient ]  ;; the arrival of new patients depends on the expected frequency in one hour
end

to setup-patient
  create-patients 1 [
    set shape "person" set size 0.9 set color 106  ;; let's beautify agents (patients)

    move-to one-of patches with [ pcolor = 9.5 and pxcor > -5 ]

    ; initialize patient's variables
    set-urgency
    set arrival-time ticks
    set arr-time-in-queue 0

    ;update monitor
    set monitor-n-of-patients monitor-n-of-patients + 1

    ;set the destination (patch) to move patient
    ifelse [free?] of one-of patches with [ name = "REG" ] = True
      [
        move-to one-of patches with [ name = "REG" ] ; if REG is free -> move to REG (registration office);
      ]
      [
        move-to  one-of patches with [ name = "WA" ] ; else -> WA (waiting area)
        set arr-time-in-queue ticks
        ask one-of patches with [ name = "REG" ] [
          set reg-queue lput myself reg-queue
        ]
      ]
    set state "waiting"
  ]
end

to set-urgency
  let rnd-n random 100
  ifelse rnd-n < 15 [ set urgency-level 1 ][
    ifelse rnd-n < 40 [ set urgency-level 2 ][
      ifelse rnd-n < 75 [ set urgency-level 3 ][
        ifelse rnd-n < 95 [ set urgency-level 4 ]
        [ set urgency-level 5 ]]]]
end

to check-working
  ask one-of patches with [ name = "REG" ]
  [
    ; patients arrived on the REG
    if any? patients-here with [state = "waiting"][
      set free? False
      ask patients-here with [state = "waiting"][
        start-service-procedure
      ]
    ]

    if not any? patients-here and not empty? reg-queue  [
      let newPat item 0 reg-queue

      set reg-queue remove-item 0 reg-queue

      ask newPat [ ; patients move from WA to REG office
        ask patch-here [set free? True]
        move-to one-of patches with [ name = "REG" ]
        ask patch-here [set free? False]

        start-service-procedure

        set waiting-time (ticks - arr-time-in-queue)
      ]
    ]
  ]

  ; check patients concluding the service to the Registration Office
  if any? patients with [state = "service"][
    ask patients with [state = "service"][
      if ticks = task-duration [
        ask patch-here [ set free? True ]
        ; update monitors
        set monitor-p-served monitor-p-served + 1
        set cycle-time (ticks - arrival-time)
        set monitor-avg-cycle-time ( (monitor-avg-cycle-time * (monitor-p-served - 1) + cycle-time) / monitor-p-served )
        set monitor-avg-wait-time ( (monitor-avg-wait-time * (monitor-p-served - 1) + waiting-time) / monitor-p-served )
        die
      ]
    ]
  ]
end

to start-service-procedure
  set state "service"

  ;compute duration for their  service
  let durat 0
  ifelse random 100 > easy-vs-difficult
     [ set durat duration-by-type-of-patient "easy" ]
     [ set durat duration-by-type-of-patient "difficult" ]
  set task-duration ticks + int(durat + durat * ( 50 - %-expert-workers ) / 100 )
end

to-report duration-by-type-of-patient [ x ]
  if x = "easy" [ report (30 + random 60) ]               ;;  1 minute
  if x = "difficult" [ report (90 + random 90) ]          ;;  3 minutes
end
@#$#@#$#@
GRAPHICS-WINDOW
264
13
737
261
-1
-1
14.1
1
10
1
1
1
0
0
0
1
-16
16
-8
8
0
0
1
ticks
30.0

BUTTON
199
190
254
235
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
142
251
199
296
GO
go\n
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
891
248
972
293
AvgCycleTime
monitor-avg-cycle-time ;/60
1
1
11

MONITOR
746
12
808
57
#Patients
monitor-n-of-patients
17
1
11

SLIDER
72
40
253
73
avg-patients-1-hour
avg-patients-1-hour
5
15
7.5
0.5
1
NIL
HORIZONTAL

MONITOR
77
251
127
296
Hour
ticks / 3600 mod 24
0
1
11

PLOT
746
63
1053
240
Ticket Service
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"served" 1.0 0 -13840069 true "" "plot monitor-p-served"

MONITOR
882
12
932
57
Served
monitor-p-served
17
1
11

MONITOR
1002
12
1052
57
Waiting
count patients with [state = \"waiting\" ]
0
1
11

OUTPUT
264
263
737
296
12

MONITOR
975
248
1053
293
AvgWaitTime
monitor-avg-wait-time
1
1
11

TEXTBOX
73
20
250
38
Arrival of patients (avg.)
15
0.0
1

TEXTBOX
789
251
875
286
  KPIs\n(seconds)
15
102.0
1

MONITOR
26
251
76
296
Day
int(ticks  / 86400)
17
1
11

BUTTON
200
263
255
296
go once
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

TEXTBOX
25
231
62
250
Time
15
103.0
1

CHOOSER
99
190
198
235
Duration
Duration
"8 hours" "1 day" "1 week"
0

MONITOR
933
12
1001
57
Registering
count patients with [state = \"service\" ]
17
1
11

SLIDER
71
95
254
128
easy-vs-difficult
easy-vs-difficult
0
100
0.0
1
1
NIL
HORIZONTAL

TEXTBOX
16
187
97
229
Simulation Setup
15
0.0
1

TEXTBOX
73
77
254
95
% of easy vs difficult cases
15
0.0
1

TEXTBOX
13
14
68
32
Factors
15
0.0
1

TEXTBOX
47
43
71
62
#1
15
0.0
1

TEXTBOX
45
99
71
118
#2
15
0.0
1

TEXTBOX
46
154
70
173
#3
15
0.0
1

TEXTBOX
72
133
222
152
% of expert workers
15
0.0
1

TEXTBOX
815
22
882
41
Response
15
0.0
1

SLIDER
72
151
253
184
%-expert-workers
%-expert-workers
0
100
100.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?



!["Switch to 3D view" (right click)](output-tvm-abm-sim.PNG)

The model describes the arrival of patients to a Registration office.

The model includes two kinds of agents:

- Patients - they perform three type of operations ("individual-ticket", "abonament", "other operations"), each one having a different duration (defined by average value: 2, 4, 6 minutes). Most part of operations involve the purchase of individual tickets (75%), then abonement (15%) and others (10%).

Each customer has a different age, which influence the speed of the operations (the age is modeled at random). Young people is faster (-20% of the expected time), while aged (over 65) are lower then the expected duration of the corresponding operation (+20%).  

-TVM: modeled as reactive agents, they perform the operation as exptected, without any behaviour. They only can broken randomly (with a very low frequency), until they are repaired. In that case, customers have to move to others TVM.

## HOW IT WORKS

- customers arrive (randomly) and wait (tvm-queue) for TVM
- each TVM serves a customer (the duration of operations is computed) 
- if more than 3 people are waiting for personnel, some customers decide to abandon with a certain probability, defined by a percentage in a slider

## HOW TO USE IT

Check KPIs about tvm workload by varying:
- the average number of arrivals in 1h [n-customer-in-one-hour]
- the different type of request (slider or manually, but their sum has to be 100) and their duration (coded as variablies) of tvm operations
- the willingness to abandon of customers in queue.

## THINGS TO NOTICE

Sometimes an TVM broken down and the corresponding people in queue move to other TVM

Worload improves by adding another tvm machines. 

## THINGS TO TRY

Change setting about arrivals.
PErform sensitivity analysis (also by using BehaviourSpace) to simulate configs.

## EXTENDING THE MODEL

1-KPIs related to number of customers served within x time, and similar
2-People can change their line if another one is free (if TVM are in the same plplace)
3- by adding more and more customers, the visualization collapse: correct the code

## RELATED MODELS

Discrete event simulation queues in ABM 

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

atm
false
0
Rectangle -7500403 true true 45 0 255 297
Polygon -16777216 false false 120 270 90 240 90 195 120 165 180 165 210 195 210 240 180 270
Rectangle -16777216 true false 169 199 177 236
Rectangle -16777216 true false 169 64 177 101
Polygon -16777216 false false 120 30 90 60 90 105 120 135 180 135 210 105 210 60 180 30
Rectangle -16777216 true false 123 64 131 101
Rectangle -16777216 true false 123 199 131 236
Rectangle -955883 false false 45 0 255 296
Rectangle -7500403 true true 60 150 225 285

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

electric outlet
false
0
Rectangle -7500403 true true 45 0 255 297
Polygon -16777216 false false 120 270 90 240 90 195 120 165 180 165 210 195 210 240 180 270
Rectangle -16777216 true false 169 199 177 236
Rectangle -16777216 true false 169 64 177 101
Polygon -16777216 false false 120 30 90 60 90 105 120 135 180 135 210 105 210 60 180 30
Rectangle -16777216 true false 123 64 131 101
Rectangle -16777216 true false 123 199 131 236
Rectangle -16777216 false false 45 0 255 296

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
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment-ATM-01" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>monitor-c-served</metric>
    <metric>monitor-abandons</metric>
    <enumeratedValueSet variable="atm-max-duration">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-impatience?">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-customers-in-1-hour">
      <value value="8"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-ATM-01-150-80-15" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>monitor-c-served</metric>
    <metric>monitor-abandons</metric>
    <enumeratedValueSet variable="atm-max-duration">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-impatience?">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-customers-in-1-hour">
      <value value="15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-ATM-01" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>monitor-c-served</metric>
    <metric>monitor-abandons</metric>
    <enumeratedValueSet variable="atm-max-duration">
      <value value="120"/>
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-impatience?">
      <value value="50"/>
      <value value="80"/>
    </enumeratedValueSet>
    <steppedValueSet variable="n-customers-in-1-hour" first="5" step="1" last="15"/>
  </experiment>
</experiments>
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

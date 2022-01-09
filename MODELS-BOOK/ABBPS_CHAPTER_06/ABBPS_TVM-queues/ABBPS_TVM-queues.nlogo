breed [ customers customer ]  ;

patches-own [
  name             ; name of next task/patch: "waiting-area","tvm"
  p-state          ; free/waiting/work
  tvm-queue        ; the queue of customers
  out-of-order-h   ; hours ou-of-order
]

customers-own [
  c-state          ; three states for customers: "moving-to-queue","waiting-in-queue","working"
  type-of-request  ; three types of operations: "individual-ticket", "abonament", "other operations"
  age              ; age of the customer
  selected-tvm     ; TVM of the customer
  dest-place       ; the phisical place in the queue
  task-duration    ; the duration of the TVM task
  arrival-time     ; the arrival time (ticks)
  beg-waiting-area ; the time of arrival in waiting area (ticks)
  end-waiting-area ; the time moving out from waiting area to next activity (ticks)
  cycle-time       ; the time from arrival to dismission at tvm
]


globals [
  ;; KPIs
  avg-cycle-time    ; KPI: time from start to exit
  avg-waiting-time  ; KPI: time from arrival in waiting area to exit

  ;; monitors
  monitor-n-of-customers   ; number of customers who need tvm
  monitor-c-served         ; number of customers served by tvm
  monitor-abandons         ; number of customers who abandon
  monitor-tvm-act          ; avg cycle-time of customers from arrival to conclusion of work at tvm
  monitor-wait-time        ; avg waiting-time of customers from arrival in waiting-area to conclusion of waiting-area
  monitor-tvm-out-of-order ; n. of tvm having problem in the whole period of the simulation
  monitor-n-individual-ticket  ; counters for type of requests
  monitor-n-abonement          ;  "
  monitor-n-other-operations   ;  "
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;                        SETUP                           ;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
 ca
 setup-world
 setup-tvm
 reset-ticks
end




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;                            GO                              ;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  tick                  ;; 1 tick = 1 second ;; 1 minute = 60 ticks ;; 60 minutes 81 hour) = 3600 ticks
  arrival-new-customers ;; procedure for new customers
  moving-customers      ;; move customers with state =  "moving-to-queue"
  check-working         ;; if a TVM is freem, the first in the queue takes the TVM and the others advance in the queue
  check-abandons        ;; verify each minute if someone prefere to abandone the queue
  vtm-out-of-order      ;; sometimes a vtm breaks down
  if ticks mod (86400 * 10)= 0 [ stop ] ;; stop condition: one day = (60 sec * 60 min * 24h) => 86400 // or one week (7 days) = 604800 ticks (7 day * 24 hours * 60 minutes * 60 seconds/ticks)
end




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;              SETUP   PROCEDURES                    ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-world ; initial procedure for creating background colors/initial setup
  output-print (word " Ticket Vendor Machines [ " n-of-tvm " ] - Simulation")
  ask patches [set name "" set pcolor 9.5]
  ask patches with [pycor <=  6] [
    ifelse pycor mod 2 = 0  [set pcolor 9][set pcolor 8]
  ]
end

to setup-tvm  ; procedure to create in an empty space (with xcor = 10) a new TVM (name of patch = "tvm")
  let i 0
  while [ i < n-of-tvm ]
  [
    let find-a-place? false
    while [ not find-a-place? ]
    [
      ask one-of patches with [ pxcor = 10 and pycor < 7 ] [
        if name != "tvm" and not any? other patches with [ name = "tvm" ] in-radius 1 [
          set pcolor gray
          set name "tvm"
          set tvm-queue []
          set find-a-place? true
          ask patch-at 1 0 [ sprout 1 [ set name "tvm-ico" set shape "square" set heading 270 set color 22 ]]
          set i i + 1
        ]
      ]
    ]
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;                GO    PROCEDURES                    ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to arrival-new-customers ; arrival of customers
  if random 3600 < n-customers-in-1-hour [ setup-customer ]   ;; the arrival of a new customer depends on the frequency expected in one hour
end

to setup-customer
  create-customers 1 [
    setxy (min-pxcor + random (max-pxcor - 1) ) 8
    set shape "person" set size 0.7 set color 103  ; let's beautify agents "customers"
    select-tvm  ; the patient selects a tvm
    set age 18 + random 63         ; age between 18 and 80 years old  // to do better with realistic distrubution age

    set arrival-time ticks         ; the initial time
    set c-state "moving-to-queue"  ; the state of the customer
    select-type                    ; the type of operation
    set monitor-n-of-customers monitor-n-of-customers + 1  ; increment the correspondin monitor
  ]
end

to select-tvm ; find a free TVM
  let n-tvm count patches with [ name = "tvm" ]
  ifelse n-tvm = 0 [
     set monitor-abandons monitor-abandons + 1
     die
  ]
  [
    ifelse n-tvm = 1 [
      set selected-tvm one-of patches with [ name = "tvm" ]
    ]
    [
      let min-value-q min map [ i -> length i ] [ tvm-queue ] of patches with [ name = "tvm" ]
      set selected-tvm one-of patches with [ name = "tvm" and length tvm-queue = min-value-q ]
    ]
    insert-cust-in-tvm-queue selected-tvm
  ]
end

to insert-cust-in-tvm-queue [ x ]  ; add the patient in the TVM queue
 ask x [ set tvm-queue lput myself tvm-queue ]
  let place-free 0

 ifelse min-pxcor <= [pxcor] of x - (length [tvm-queue] of x) [
    set place-free patch ([pxcor] of x - (length [tvm-queue] of x)) [pycor] of x
  ]
  [
    set place-free patch (min-pxcor + 1)  [pycor] of x
  ]

  if (xcor = 0 and ycor = 0 ) [set heading 270 fd 3]  ; just a trick to avoid a positioning error
  set heading towards place-free
  set dest-place place-free
end

to select-type
  if individual-ticket + abonement + other-operations != 100 [ reset-type ]
  if random 100 < individual-ticket [ set type-of-request "individual-ticket"]
  if random 100 < abonement [ set type-of-request "abonement"]
  if random 100 < other-operations [ set type-of-request "other-operations"]
  let rnd-req ["individual-ticket" "abonement" "other-operations"]
  if type-of-request = 0 [ set type-of-request one-of rnd-req ]
end

to reset-type
  set individual-ticket 75
  set abonement 15
  set other-operations 10
end


to moving-customers ;; moving customers with state = "moving-to-queue"
  ask customers with [ c-state = "moving-to-queue" ][
    set heading towards dest-place
    fd 1        ;; each tick/second takes 1 units, i.e. 1 seconds each step

    if patch-here = dest-place [
      set c-state "waiting-in-queue"
      set heading towards selected-tvm
    ]
  ]
end


to check-working
  let queue-not-empty filter [ i -> length i != 0 ] [ tvm-queue ] of patches with [ name = "tvm" ]

  foreach queue-not-empty
    [
      q ->
      ask first q [
        if not any? customers-on selected-tvm [
          move-to selected-tvm
          set color sky
          set avg-waiting-time (ticks - arrival-time)
          set c-state "working"
          set task-duration ticks + int(duration-by-type-of-request type-of-request * factor-age age * other-people-waiting (length q))  ;; duration depends on several factors
          ask selected-tvm [set tvm-queue  remove-item 0  tvm-queue ]

          ;if length q < 20 [
            if any? other customers with [selected-tvm = [selected-tvm] of myself][   ;; update all the other customers in the correponding queue
              ask other customers with [selected-tvm = [selected-tvm] of myself]
              [
                if c-state = "waiting-in-queue" [ set heading towards selected-tvm fd 1 ]    ;; people already in queue advance horizzontally of 1
                if c-state = "moving-to-queue" [
                  set dest-place one-of patches with [pxcor = ([pxcor] of [dest-place] of myself + 1) and pycor = [pycor] of [dest-place] of myself ]
                ]
              ]
          ;  ]
          ]
        ]
      ]
  ]

  ask customers with [c-state = "working"][
    if ticks = task-duration [
      set avg-cycle-time (ticks - arrival-time)
      set monitor-c-served monitor-c-served + 1
      set monitor-tvm-act ( (monitor-tvm-act * (monitor-c-served  - 1) + avg-cycle-time) / monitor-c-served )
      set monitor-wait-time ( (monitor-wait-time * (monitor-c-served  - 1) + avg-waiting-time) / monitor-c-served )

      if type-of-request = "individual-ticket" [set monitor-n-individual-ticket monitor-n-individual-ticket + 1] ; counters for type of requests
      if type-of-request = "abonement" [set monitor-n-abonement monitor-n-abonement + 1]
      if type-of-request = "other-operations" [set monitor-n-other-operations  monitor-n-other-operations + 1]
      die
    ]
  ]
end


to-report duration-by-type-of-request [ x ]
  if x = "individual-ticket" [ report 120 ]   ;;  2 minutes
  if x = "abonement" [ report 300 ]           ;;  5 minutes
  if x = "other-operations" [ report 360 ]    ;;  6 minutes
end

to-report factor-age [ a ]
  ifelse a < 26 [report 0.8]      ;; speeding up young agents (18-25 yo)
   [
      ifelse a > 65 [report 1.2]  ;; slowing down the elderly (over 65 yo)
      [ report 1
      ]
  ]
end


to-report other-people-waiting [ len-queue ]
  if len-queue = 1 [ report 1.1 ]
  if len-queue > 1 and len-queue < 4 [ report 0.9 ]
  if len-queue >= 4 [ report 0.8 ]
end

to check-abandons
  if ticks mod 600 = 0 [   ; every 5 minutes check & compute the prob. of abandons
    ask customers with [c-state = "waiting-in-queue"][
      let lenTVM [tvm-queue] of selected-tvm
      if length(lenTVM) > 2 and random 100 < int(log length(lenTVM) 10 *  100)  and random(100) < queue-impatience?  [
        let impatient-customer (last lenTVM)      ; remove one customer from queue
        ask selected-tvm [set tvm-queue (but-last lenTVM)]
        ask impatient-customer
        [
          set monitor-abandons monitor-abandons + 1
          die
        ]
      ]
    ]
  ]
end

to vtm-out-of-order
  if ticks mod 3600 = 0 ; each hour an ATM can go out-of-order with a certain (low) probability
    [ ask patches with [name = "tvm"]
      [
        if random (120 * n-of-tvm) = 1   ; about every 10 days - each hour: prob = 1 / (24 * 10) - one VTM broke down for some hours (between 2 to 10h)
        [
          set pcolor 13 output-print " * * * TVM out of order! * * * " wait 1
          set name "tvm-out-of-order"
          set out-of-order-h ticks + 3600 + random 86400
          set monitor-tvm-out-of-order monitor-tvm-out-of-order + 1
          move-to-queue tvm-queue
          set tvm-queue []
        ]
      ]
  ]

  ask patches with [name = "tvm-out-of-order"]
  [
    if out-of-order-h = ticks [
      set name "tvm"
      clear-output output-print (word " Ticket Vendor Machines [ " n-of-tvm " TVM ] - Simulation") wait 1
      set monitor-tvm-out-of-order monitor-tvm-out-of-order - 1
      set pcolor gray
    ]
  ]
end

to move-to-queue [ out-que ]
  foreach out-que
  [
    x -> ask x [
      ifelse count patches with [ name = "tvm" ] > 0 [
        let min-value-q min map [ i -> length i ] [ tvm-queue ] of patches with [ name = "tvm" ]
        set selected-tvm one-of patches with [ name = "tvm" and length tvm-queue = min-value-q ]
        insert-cust-in-tvm-queue selected-tvm
        set c-state "moving-to-queue"
      ][
        set monitor-abandons monitor-abandons + 1
        die
      ]
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
282
10
719
240
-1
-1
13.0
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
56
251
123
297
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
141
251
204
297
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
845
249
939
294
AvgCycleTime
monitor-tvm-act / 60
1
1
11

MONITOR
878
10
951
55
Customers
monitor-n-of-customers
17
1
11

SLIDER
87
154
273
187
n-customers-in-1-hour
n-customers-in-1-hour
1
60
42.0
1
1
NIL
HORIZONTAL

MONITOR
817
10
867
55
Hour
ticks / 3600 mod 24
0
1
11

SLIDER
127
205
273
238
queue-impatience?
queue-impatience?
10
100
60.0
1
1
NIL
HORIZONTAL

MONITOR
1012
10
1085
55
Abandons
monitor-abandons
17
1
11

PLOT
729
62
1048
239
ATM service
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
"abandons" 1.0 0 -955883 true "" "plot monitor-abandons"
"served" 1.0 0 -13840069 true "" "plot monitor-c-served"

MONITOR
961
10
1011
55
Served
monitor-c-served
17
1
11

MONITOR
1086
10
1136
55
Waiting
count customers-on patches with [name = \"waiting-area\"]
0
1
11

OUTPUT
282
242
720
296
12

MONITOR
758
249
844
294
AvgWaitTime
monitor-wait-time / 60
1
1
11

SLIDER
130
12
273
45
n-of-tvm
n-of-tvm
1
6
3.0
1
1
NIL
HORIZONTAL

SLIDER
86
49
273
82
individual-ticket
individual-ticket
0
100
75.0
1
1
NIL
HORIZONTAL

SLIDER
86
82
273
115
abonement
abonement
0
100
15.0
1
1
NIL
HORIZONTAL

SLIDER
86
115
273
148
other-operations
other-operations
0
100
10.0
1
1
NIL
HORIZONTAL

BUTTON
4
115
78
148
reset-type
reset-type
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
64
84
101
Type of \nrequests
13
0.0
1

TEXTBOX
16
20
123
38
Number of TVM:
13
103.0
1

TEXTBOX
18
164
67
182
Arrivals
13
62.0
1

TEXTBOX
4
195
121
243
Impatience rate \n(% leaving if\nlength queue > x)
13
0.0
1

TEXTBOX
731
263
766
281
KPIs
13
93.0
1

MONITOR
940
249
1048
294
Rate of aband.
monitor-abandons * 100 / (monitor-c-served + monitor-abandons)
1
1
11

MONITOR
766
10
816
55
Day
int(ticks  / 86400)
17
1
11

MONITOR
1056
249
1136
294
TVM-KO
monitor-tvm-out-of-order
17
1
11

BUTTON
206
257
261
290
NIL
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
728
22
766
41
Time
13
93.0
1

MONITOR
1056
149
1136
194
Abonements
monitor-n-abonement
0
1
11

MONITOR
1056
104
1136
149
N-ticket
monitor-n-individual-ticket
17
1
11

MONITOR
1056
194
1136
239
Other
monitor-n-other-operations
0
1
11

TEXTBOX
1065
65
1133
97
Solved requests
13
53.0
1

@#$#@#$#@
## WHAT IS IT?

!["Switch to 3D view" (right click)](output-tvm-abm-sim.PNG)

The model concerns the arrival of customers to Ticket Vending Machines (TVM).

Customers perform three type of operations ("individual-ticket", "abonament", "other operations"), each one having a different duration (defined by average value: 2, 4, 6 minutes). Most part of TVM operations involve the purchase of individual tickets (75%), then abonement (15%) and others (10%).

Each customer has a different age, which influence the speed of the operations (the age is modeled at random). Young people is faster (-20% of the expected time), while aged (over 65) are lower then the expected duration of the corresponding operation (+20%).  

TVM performs the exptected operations. They only can broken randomly (with a very low frequency), until they are repaired. In the case of a broken TVM, the corresponding customers have to move to another TVM.

## HOW IT WORKS

The phases are:
- customers arrive (randomly) and wait in a queue (tvm-queue) for TVM
- each TVM serves a customer (the duration of operations is computed) 
- if more than 3 people are waiting for personnel, some customers decide to abandon (with a certain probability, defined by a percentage in a slider)

## HOW TO USE IT

Check KPIs about TVM workload by varying:
- the average number of arrivals in 1h [n-customer-in-one-hour]
- the different type of request (slider or manually, but their sum has to be 100) and their duration (coded as variablies) of TVM operations
- the willingness to abandon of customers in queue.

## THINGS TO NOTICE

If the sum of (the relatives percentage of "individual-ticket" + "abonements" + "other operations" is not 100, then the program automatically reset a default type configuration.

Sometimes a TVM broken down and the corresponding customers in queue move to another TVM.

## THINGS TO TRY

Change setting about arrivals. 
Service time worsens or improves by considering different range of ages, as well as by removing or adding one or more TVM machines. 

Perform sensitivity analysis to simulate different configs (e.g, by using BehaviourSpace).

## EXTENDING THE MODEL

Add KPIs related to the number of customers served within a certain amount of time

People can change their line if another one is free

Improve the code to avoid the visualization collapse by adding too much more customers

## RELATED MODELS

Discrete event simulation queues in professional ABM tools.

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
NetLogo 6.2.1
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

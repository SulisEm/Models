extensions [ xes table ]

breed [ tasks task]
breed [ workers worker ]


globals [
  resources
  activities

  dAcDu ; dict with activities and duration
  dAcCo ; dict with activities and costs
  dAcFr ; dict with activities and frequency

  dTrFr ; dict with each trace and their frequency
  dSeFr ; dict with a sequence and the corresponding frequency
  dPaFr ; dict with a pair of activities and their frequency

  globalEventAttributes

  startEvent     ; initial event
  endEvents ; end event

  startTasks     ; initial task
  endTasks  ; end task

  not-concurrent-relations
  concurrent-relations

  events
  traces
]

turtles-own [ name ]
links-own [ weight ]


;;;;;;;;;;;;;;    SETUP   ;;;;;;;;;;;;;;;;;;;

to setup

  clear-all
  ask patches [set pcolor white]
  file-close-all ; Close any files open from last run
  setup-variables
  reset-ticks
end


to setup-variables
  set activities []
  set resources []
  set dAcDu table:make  ; a sequence and their duration
  set dAcCo table:make  ; an activity and their cost
  set dAcFr table:make  ; an activity and the corresponfig frequency
  set dPaFr table:make  ; a pair of activities and their frequency
  set dSeFr table:make  ; a sequence and their frequency
  set dTrFr table:make
end



to read-turtles-xes
  file-close-all ; close all open files

  let data []

  ; open the file chosen by user
  carefully [ set data xes:from-file   "general_example.xes" ;"running-example.xes"  ;"BPI_Challenge_2012_filtered_simple_heuristic.xes";    "Road_Traffic_Fine_Management_Process.xes"  ;"general_example.xes" ; user-file ;"CCC19 - Log XES.xes";
  ] [ print "Cancelled operation or exception occurred. See logs." ]

  let id_trace ""

  foreach data [ row ->
    ;WITH LoL we refer to List Of Lists
    let extensionData item 0 row ;LoL where you have the name, prefix, and a string representing a URI at pos 0,1,2
    set globalEventAttributes item 1 row ;LoL: key at pos 0 and value at pos 1 of the resulting list
    let traceEventAttributes item 2 row ;LoL: key at pos 0 and value at pos 1 of the resulting list
    let classifiers item 3 row ;LoL: name at pos 0, and another list containing the keys
    let logsKey item 4 row ;LoL: key on pos0 and value on pos1
    set traces item 5 row ;LoL: key on pos0 and value on pos1

    foreach traces [
      trace ->

      let events-in-a-trace []

      ; search ID value for each trace
      let traceKey item 0 trace  ;;; type "\t traceKey:"
      foreach tracekey [
        t ->
        if "concept:name" = item 0 t [
          set id_trace item 1 t ; the concept-name
        ]
      ]

      let act ""  ; used to create pairs of activities to count frequency/occurrences
      set events item 1 trace
      foreach events [
        eventAggregated ->        ; show filter [ eve -> item 0 eve = "ROUND" ] eventAggregated
        let costo 0
        let activity ""

        foreach eventAggregated [
          ev ->
          if item 0 ev = "Activity" [
            set activity item 1 ev

            set dAcFr increament-dict dAcFr activity

            set events-in-a-trace lput activity events-in-a-trace   ; add in a list with all events of the trace
            if not member? activity activities  [set activities lput activity activities ]  ; just add a new activity to the list of activities
            ifelse act = "" [ set act activity ]
            [  let pair list act activity
               set dPaFr increament-dict dPaFr pair
               set act activity
            ]
          ]

          if item 0 ev = "Costs" [
            set costo item 1 ev
          ]

          if item 0 ev = "Resource" and not member? (item 1 ev) resources [
            set resources lput (item 1 ev) resources
          ]

          if not member? activity table:keys dAcCo and activity != ""
          [
            table:put dAcCo activity costo
          ]
        ]
        set traces lput events-in-a-trace traces
      ]
      set dTrFr increament-dict dTrFr events-in-a-trace
    ]
  ]

  file-close ; make sure to close the file
end

to viz-workers
  foreach resources
  [ r -> create-workers 1 [ set name r set shape "person" set size 0.6 set  color gray setxy (dispose-workers min-pxcor max-pycor) max-pycor ]]
end

to-report dispose-workers [ x y ]

  ifelse any? workers-on patch x y and x < max-pxcor [
    set x (x + 1)
    report dispose-workers x y
  ][
    report x
  ]

end
to viz-stats
  clear-output
  output-print (word "* EVENT LOG DESCRIPTION *")
  output-print (word "Global Events Attributes: ")
  foreach globalEventAttributes [x -> output-print (word " - " item 0 x ";")]
end

to viz-resources
  output-print (word "\nNumber of agents: " length(resources) ";")
  output-print (word "Name of agents: " resources ";")
end

to viz-activities
  output-print (word "\nNumber of activities: " length(activities) ";")
  output-print (word "Name of activities: ")
  foreach activities [
    a ->
    output-print (word " - " a " ")
    create-tasks 1 [
      fd random 10 set shape "task" set size 1 set name a set label name set color black set label-color black
    ]
  ]
end

to viz-DFG
  foreach table:keys dPaFr [
    pa ->
    ask one-of tasks with [name = item 0 pa]  [create-links-to tasks with [name = item 1 pa] [set weight table:get dPaFr pa set thickness normalized-value weight set label weight] ]
  ]
  repeat 300 [ layout-spring tasks links 1 5 35 ]  ;;layout-spring turtle-set link-set spring-constant spring-length repulsion-constant
end

to viz-costs
  output-print (word "\nList of activities and costs:")
  foreach activities [
    a ->
    output-print (word " - " a ": " table:get dAcCo a)
  ]
end

to directly-follow-graph
  ; insert here just the operations to produce DFG

end

to discover-concurrency-relations
  set not-concurrent-relations []
  set concurrent-relations []
  output-print ("Concurrent relations:")
  foreach table:keys dPaFr
  [ pair ->
    let invPair list item 1 pair item 0 pair
    ifelse not member? invPair table:keys dPaFr
    [
      if not member? pair not-concurrent-relations and not member? invPair not-concurrent-relations [ set not-concurrent-relations lput pair not-concurrent-relations ]
    ]
    [
      if not member? pair concurrent-relations and not member? invPair concurrent-relations  [
        set concurrent-relations lput pair concurrent-relations
      output-print (word " - " item 0 pair " || " item 1 pair )]
    ]
  ]
end


to pruned-DFG
  foreach concurrent-relations [
    pa ->
    ask one-of tasks with [name = item 0 pa ]
      [ ask out-link-to  one-of tasks with [name = item 1 pa] [die] ]
    ask one-of tasks with [name = item 1 pa ]
      [ ask out-link-to  one-of tasks with [name = item 0 pa] [die] ]
  ]
end


to define-causality

end


to filtering-algorithm
  let toVisit []
  let unvisited []

  ; initialize each node to 0...
  let bestPredecessorFromSource table:make
  let bestSuccessorToSink table:make

  let maxCapacitiesFromSource table:make
  let maxCapacitiesToSink table:make

  ask tasks [
    table:put maxCapacitiesFromSource [name] of self 0
    table:put maxCapacitiesToSink [name] of self 0
  ]

  foreach startEvent [
    ev -> table:put maxCapacitiesFromSource ev 99999
  ]
  foreach endEvents  [
    ev -> table:put maxCapacitiesToSink ev 99999
  ]

  ;; discover maximum source-to-node capacity
  ; forward exploration
  set toVisit startTasks
  set unvisited turtle-set tasks ;
  foreach startTasks [   ;removing startTasks from unvisited
    t ->
    if member? t unvisited [
      set unvisited unvisited with [self != t]
    ]
  ]

  while [not empty? toVisit][
    let src first toVisit  set toVisit remove-item 0 toVisit
    let cap table:get maxCapacitiesFromSource [name] of src

    ask src [
      ask my-out-links [
        let tgt other-end

        let maxCap 0 ifelse cap > weight [ set maxCap weight ][ set maxCap cap ]
        if maxCap > table:get maxCapacitiesFromSource [name] of tgt[
          table:put maxCapacitiesFromSource [name] of tgt maxCap
          table:put bestPredecessorFromSource [name] of tgt self
          if not member? tgt toVisit  [ set unvisited (turtle-set tgt unvisited) ]
        ]

        if member? tgt unvisited [
          set toVisit lput tgt toVisit
          set unvisited unvisited  with [self != tgt]  ; remove me from agentset ;remove tgt unvisited
        ]
      ]
    ]

  ]

  set toVisit endTasks
  set unvisited turtle-set tasks ;
  foreach endTasks [
    t ->
    if member? t unvisited [
      set unvisited unvisited with [self != t]
    ]
  ]

  while [not empty? toVisit][
    let tgt first toVisit  set toVisit remove-item 0 toVisit
    let cap table:get maxCapacitiesToSink [name] of tgt

    ask tgt [
       ask my-in-links [
        let src other-end

        let maxCap 0 ifelse cap > weight [ set maxCap weight ][ set maxCap cap ]

        if maxCap > table:get maxCapacitiesToSink [name] of src[
          table:put maxCapacitiesToSink [name] of src maxCap
          table:put bestSuccessorToSink [name] of src self

          if not member? src toVisit  [ set unvisited (turtle-set src unvisited) ]
        ]

        if member? src unvisited [
          set toVisit lput src toVisit
          set unvisited unvisited with [self != src]

        ]
      ]
    ]
  ]

  let bestEdges []
  ask tasks [
    if member? [name] of self table:keys bestPredecessorFromSource
    [ set bestEdges lput table:get bestPredecessorFromSource [name] of self bestEdges ]

    if member? [name] of self table:keys  bestSuccessorToSink
    [  set bestEdges lput table:get bestSuccessorToSink [name] of self bestEdges ]
  ]
  foreach bestEdges [
    l -> ask l [
      if weight < filter-value [
        die
      ]

    ]
  ]
end

to find-start-events
  set startEvent []
  set startTasks []

  foreach table:keys dTrFr
  [ v ->
    if not member? item 0 v startEvent
      [
        set startEvent lput item 0 v startEvent
        set startTasks lput one-of tasks with [name = item 0 v] startTasks
      ]
  ]
  output-print (word  "Start event(s): " startEvent)
  foreach startTasks [
    t -> ask t [set color green]
  ]
end

to find-end-events
  set endEvents []
  set endTasks []

  foreach table:keys dTrFr
  [ v ->
    if not member? last v endEvents
      [
        set endEvents lput last v endEvents
        set endTasks lput one-of tasks with [name = last v] endTasks
      ]
  ]
  output-print (word "End event(s): " endEvents)
  foreach endTasks [
    t -> ask t [set color orange]
  ]
end


;;; UTILS
to-report increament-dict [d v]
  ifelse member? v table:keys d
  [table:put d v table:get d v + 1]
  [table:put d v 1]
  report d
end
to-report normalized-value [v]
  report sqrt (v / 50)
end

to loga [x]
  let i 0
  while [i < x]
  [
    set i i + 1
  ]
end

; RELEASED WITH GNU General Public License v3.0
@#$#@#$#@
GRAPHICS-WINDOW
231
17
668
455
-1
-1
13.0
1
11
1
1
1
0
0
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
59
27
169
61
Read XES File
setup\nread-turtles-xes
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

OUTPUT
692
8
1092
508
11

BUTTON
140
82
216
116
Attributes
viz-stats
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
115
202
202
236
Vis. Tasks
viz-activities
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
549
456
669
489
clear output-area
clear-output
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
30
8
229
27
Importing a real-life log (XES)
14
0.0
1

TEXTBOX
39
64
164
84
Business process statistics
14
103.0
1

BUTTON
231
456
341
489
clear all
ca
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
47
312
217
346
DIRECT FOLLOWER GRAPH
viz-DFG
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
140
150
216
184
Costs
viz-costs
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
30
202
113
236
Vis. Staff
viz-workers
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
30
269
113
303
Start Event
find-start-events
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
115
269
202
303
End Event
find-end-events
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
16
456
133
490
Concurrent relat.
discover-concurrency-relations
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
134
456
211
490
NIL
pruned-DFG
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
151
347
216
392
# Links
count links
17
1
11

BUTTON
134
421
211
455
Filtering
filtering-algorithm
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
16
421
133
454
filter-value
filter-value
1
10
2.0
1
1
NIL
HORIZONTAL

MONITOR
7
347
81
392
# Workers
count workers
17
1
11

MONITOR
82
347
150
392
# Tasks
count tasks
17
1
11

TEXTBOX
37
91
144
110
Events Attributes:
12
0.0
1

BUTTON
140
116
216
150
Resources
viz-resources
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
106
124
138
142
Staff:
12
0.0
1

TEXTBOX
28
158
140
177
Activities and Costs:
12
0.0
1

TEXTBOX
30
187
209
206
Visualize Staff and Activities
14
103.0
1

TEXTBOX
64
239
169
258
Color the events 
14
103.0
1

TEXTBOX
38
252
202
271
[green >> start -- red >> end]
11
0.0
1

TEXTBOX
12
320
45
338
DFG:
16
103.0
1

TEXTBOX
18
404
151
423
Improve visualisation
14
103.0
1

@#$#@#$#@
## WHAT IS IT?

This model imports a real-life Event Log in XES format to analyse main features and attributes, as well as represent a Direct Follower Graph

The Direct Follower Graph is a graphical representation of a business process widely used in Process Mining. 

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

This model is automatically generated from the Event Log, whereas the cycle time and frequency of links are visualized directly on the graph.

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

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

task
false
0
Circle -7500403 true true 30 30 240
Circle -1 true false 45 45 210

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
NetLogo 6.0.4
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

extensions [gis csv nw]

breed [nodes node]

globals [world-dataset csv monit-it monit-ita monit-ger monit-fra monit-usa monit-rus monit-chi monit-day envelope]

links-own [weight]

nodes-own [name country time]

to settup
  ca
  gis:load-coordinate-system "countries.prj"

  ; Load the dataset
  set world-dataset gis:load-dataset "countries.shp"

  ; Drawing country boundaries from a shapefile
  gis:set-drawing-color white
  gis:draw world-dataset 0.3

  set envelope gis:world-envelope

  print envelope
end

to setup
  ca

  ; Note that setting the coordinate system here is optional
  gis:load-coordinate-system "countries.prj"

  ; Load the dataset
  set world-dataset gis:load-dataset "countries.shp"

  set envelope gis:world-envelope

  ; Drawing country boundaries from a shapefile
  gis:set-drawing-color white
  gis:draw world-dataset 0.3
end

to openGIS
  setup

  gis:set-world-envelope envelope

  let latit  45.6860230
  let longi 8.9365760

  let xscale (max-pxcor - min-pxcor) / (item 1 envelope - item 0 envelope)
  let yscale (max-pycor - min-pycor) / (item 3 envelope - item 2 envelope)
  let netlogo-x (longi  - item 0 envelope) * xscale + min-pxcor
  let netlogo-y (latit - item 2 envelope) * yscale + min-pycor

  create-nodes 1 [ set name "Company" set color green  set size 2 set shape "house" setxy netlogo-x netlogo-y ]
end

to openNetwork
  ifelse kindNetwork = "from Vendors" [
    print openNet "fromVendors.csv"
  ][
    ifelse kindNetwork = "to Customers" [
      print openNet "toCustomers.csv"
      ][if kindNetwork = "from and to Subcontractors" [
        print openNet "fromSubconts.csv"
        print openNet "toSubconts.csv"
      ]]]
  ask nodes with [who > 0][set size 1 set shape "dot"]
end

to-report openNet[namefile]
  file-open nameFile
  let fileList []

  let i 0
  while [not file-at-end?] [
   set csv file-read-line
    if i > 0 [
    set csv word csv ","; Example from CSV file: 2017-04-26,GOERLACH  BESATZSCHMUCK  GmbH, 2, 5, 47.8804, 10.6222
    let mylist []
    while [not empty? csv]
    [
      let $x position "," csv ; use "\t" for tsv file
      let $item substring csv 0 $x  ; extract item

      carefully [set $item read-from-string $item][] ; convert if number
      set mylist lput $item mylist  ; append to list
      set csv substring csv ($x + 1) length csv  ; remove item and comma
    ]
    set fileList lput mylist fileList
  ]
  set i  i + 1
  ]

  foreach filelist
  [ x -> ;    ;;;  Example from CSV file: x = [2017-04-21 METALLURGICA LOMBARDA SRL 12 0 45.3987 8.91623]

    let data item 0 x
    let comp item 1 x  let n item 2 x

    ifelse not any? nodes with [name = comp]  ; create node if not exists...
    [ create-nodes 1
      [
        let latit item 4 x ;  latitude of other company
        let longi item 5 x ;  longitude of other company

        let xscale (max-pxcor - min-pxcor) / (item 1 envelope - item 0 envelope)
        let yscale (max-pycor - min-pycor) / (item 3 envelope - item 2 envelope)

        let netlogo-x (longi - item 0 envelope) * xscale + min-pxcor
        let netlogo-y (latit - item 2 envelope) * yscale + min-pycor

        set name comp set color red  set time data setxy netlogo-x netlogo-y

        ask nodes with [name = comp] [ create-link-to turtle 0 [ set weight n ] ] ] ]
    [
      ask nodes with [name = comp] [ask link who 0 [ set weight weight + n  ] ] ]  ; otherwise, increase weight of existing link
  ]

  file-close
  report "Created Network"
end

to set-monitors-cont-countries
  set monit-ita 0  set monit-ger 0  set monit-fra 0  set monit-rus 0 set monit-chi 0   set monit-usa 0
  ask turtles [
    foreach gis:feature-list-of world-dataset [
      v -> if gis:intersects? v self [
        if gis:property-value v "LONG_NAME" = "Italy"[set monit-ita monit-ita + 1]
        if gis:property-value v "LONG_NAME" = "France"[set monit-fra monit-fra + 1]
        if gis:property-value v "LONG_NAME" = "Germany"[set monit-ger monit-ger + 1]
        if gis:property-value v "LONG_NAME" = "China"[set monit-chi monit-chi + 1]
        if gis:property-value v "LONG_NAME" = "Russia"[set monit-rus monit-rus + 1]
        if gis:property-value v "LONG_NAME" = "United States"[set monit-usa monit-usa + 1]
  ]]]
end

to prune
  ask links [if weight <= Weight-Min [die]]
  ask nodes with [count my-links = 0] [die]
end

to open-temporal

  ca

  openGIS

  file-close-all
  file-open "tempNetw.csv"
  reset-ticks

  let headings file-read-line

  let fileList []  let tempo 0

  while [not file-at-end?]
  [
    let x csv:from-row file-read-line

    let d item 4 x

    if d > 0 [ wait 1.2 - VizSpeed / 10 tick set tempo tempo + ticks ]

    let tipo item 0 x
    let data item 1 x
    let comp item 2 x
    let n item 3 x

    set monit-day data

    ifelse not any? nodes with [name = comp]  ; create node if not exists...
      [ create-nodes 1
        [ set size 1 set shape "dot"
          let latit item 5 x  let longi item 6 x ;  latitude and longitude of other company

          let xscale (max-pxcor - min-pxcor) / (item 1 envelope - item 0 envelope)
          let yscale (max-pycor - min-pycor) / (item 3 envelope - item 2 envelope)

          let netlogo-x (longi - item 0 envelope) * xscale + min-pxcor
          let netlogo-y (latit - item 2 envelope) * yscale + min-pycor

          set name comp set color red set time tempo setxy netlogo-x netlogo-y

          ifelse tipo = "S" or tipo = "daT" [
            ask nodes with [name = comp] [ create-link-to turtle 0 [ set weight n ] ] ]
          [  ask nodes with [name = comp] [ create-link-from turtle 0 [ set weight n ] ] ] ] ]
      [
        ask nodes with [name = comp] [
        if not empty? sort my-links
        [ ask my-links [ set weight weight + n  ] ] ]  ; otherwise, increase weight
    ]
  ]
  file-close
end


to compute-network-metrics
  clear-output
  output-print (word "Avg.Deg: " precision ([ sum [ weight ] of my-links ] of node 0  / count nodes) 5 )
  output-print (word "Density: " precision (count links / (count nodes * (count nodes - 1) / 2) ) 5 )
  ;;output-print (word nw:mean-weighted-path-length weight)
  ;;output-print [ sum [ weight ] of my-links ] of node 0
end



to create-N
  ca

  create-nodes 1 [ set label "Company" set color orange set size 2.5 set shape "house" setxy 0 0 ]

  file-open "aclien.csv"
  let fileList []

  let i 0
  while [not file-at-end?] [
   set csv file-read-line
    if i > 0 [
    set csv word csv "\t"  ; add comma for loop termination
    let mylist []  ; list of values
    while [not empty? csv]
    [
      let $x position "\t" csv
      let $item substring csv 0 $x  ; extract item
      carefully [set $item read-from-string $item][] ; convert if number
      set mylist lput $item mylist  ; append to list
      set csv substring csv ($x + 1) length csv  ; remove item and comma
    ]
    set fileList lput mylist fileList

  ]
  set i  i + 1
  ]

  foreach filelist
  [ x ->
    let data item 0 x ; name of other company
    let comp item 1 x
    let n item 2 x
    let d item 3 x
 ifelse not any? nodes with [name = comp]  ; create node if not exists...
      [
    create-nodes 1 [ set name comp set color blue  setxy random-xcor random-ycor
      create-link-from turtle 0 [ set weight n ] ]
  ]

  [
        ask nodes with [name = comp] [
        if not empty? sort my-links
        [ ask my-links [ set weight weight + n  ] ] ] ]

  file-close

  if lab-N [ask nodes [set label name]]
  ]
end













to u
  show gis:property-names world-dataset
end

to c
  ask node 0
  [
    ;:set label gis:property-value vector-feature "LONG_NAME"
  ]
end

to ooo
  foreach gis:feature-list-of world-dataset [ x -> ask turtles-here [set country gis:property-value x "LONG_NAME" ]]
end






to createLinks
  let l []; sort nodes in a list
  ask nodes  [set l lput self l]
  set l remove-item 0 sort l
  ask node 0 [
    create-links-with turtle-set sort l [set weight random 10]
  ]
end

to-report average-shortest-path-length
  report nw:mean-path-length
end

to o
  foreach gis:feature-list-of world-dataset [ x -> show gis:property-value x "LONG_NAME" ]
end

to openFile
  file-open "dati-sim.csv"
  let fileList []

  while [not file-at-end?] [
    set csv file-read-line
    set csv word csv ";"  ; add comma for loop termination

    let mylist []  ; list of values
    while [not empty? csv]
    [
      let $x position "," csv
      let $item substring csv 0 $x  ; extract item
      carefully [set $item read-from-string $item][] ; convert if number
      set mylist lput $item mylist  ; append to list
      set csv substring csv ($x + 1) length csv  ; remove item and comma
    ]
    set fileList lput mylist fileList
  ]

  show  fileList

  file-close
end


to p
  set-default-shape nodes "circle"

  let latitude 55.7507
  let longitude 37.6177

  gis:set-world-envelope envelope

  show envelope

  let xscale (max-pxcor - min-pxcor) / (item 1 envelope - item 0 envelope)
  let yscale (max-pycor - min-pycor) / (item 3 envelope - item 2 envelope)
  let netlogo-x (longitude - item 0 envelope) * xscale + min-pxcor
  let netlogo-y (latitude - item 2 envelope) * yscale + min-pycor

  crt 1 [ set color red set size 5 set shape "dot" setxy netlogo-x netlogo-y ]
end

to check-interactions
  let count-US 0
  let count-GER 0
  let count-FRA  0

  let IT gis:find-features world-dataset  "SOVEREIGN" "Italy"
  let US gis:find-features world-dataset  "SOVEREIGN" "United States"
  let GER gis:find-features world-dataset  "SOVEREIGN" "Germany"
  let FRA gis:find-features world-dataset  "SOVEREIGN" "France"
  let RUS gis:find-features world-dataset  "SOVEREIGN" "Russia"
  let CHI gis:find-features world-dataset  "SOVEREIGN" "China"


  ask nodes [
    if gis:intersects? IT self [
      set color white
    ]
    if gis:intersects? US self [
      set color pink
    ]
    if gis:intersects? CHI self [
      set color cyan
    ]
    if gis:intersects? RUS self [
      set color green
    ]
    if gis:intersects? GER self [
      set color yellow
    ]
    if gis:intersects? FRA self [
      set color sky
    ]

  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
328
10
1191
474
-1
-1
5.0
1
12
1
1
1
0
0
1
1
-85
85
-45
45
0
0
1
ticks
30.0

BUTTON
236
11
320
44
SETUP
openGIS
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
214
109
247
Compute
compute-network-metrics
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
210
125
265
170
NODES
count nodes
17
1
11

MONITOR
20
303
70
348
ITA
monit-ita
17
1
11

TEXTBOX
20
54
255
73
2 - Create Nodes and Edges for:
15
92.0
1

TEXTBOX
21
16
250
54
1 - Setup and create Company:
15
22.0
1

TEXTBOX
24
174
149
209
3 - Compute Network Metrics:
15
13.0
1

TEXTBOX
63
135
214
154
Main network metrics
15
63.0
1

MONITOR
266
125
320
170
EDGES
count links
17
1
11

BUTTON
143
265
320
298
Count Third Parties by Country
set-monitors-cont-countries
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
70
303
120
348
FRA
monit-FRA
17
1
11

MONITOR
120
303
170
348
GER
monit-ger
17
1
11

MONITOR
170
303
220
348
CHI
monit-chi
17
1
11

MONITOR
220
303
270
348
RUS
monit-rus
17
1
11

MONITOR
270
303
320
348
USA
monit-usa
17
1
11

BUTTON
108
441
163
474
Create
create-N
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
168
441
268
474
Weight-Min
Weight-Min
1
150
110.0
1
1
NIL
HORIZONTAL

BUTTON
268
441
323
474
NIL
prune
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
18
441
108
474
lab-N
lab-N
1
1
-1000

CHOOSER
27
76
208
121
KindNetwork
KindNetwork
"to Customers" "from Vendors" "from and to Subcontractors"
0

BUTTON
210
77
320
122
NIL
openNetwork
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
112
382
193
415
Dyn.Netw.
open-temporal
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
18
382
112
415
VizSpeed
VizSpeed
0
5
1.0
1
1
NIL
HORIZONTAL

OUTPUT
145
180
321
253
11

TEXTBOX
21
270
171
289
4 - Data analysis
15
53.0
1

TEXTBOX
22
422
172
441
6 - Visualize Network
15
112.0
1

TEXTBOX
23
363
173
382
5 - Temporal Network
15
33.0
1

MONITOR
272
377
322
422
AvDeg
precision ([ sum [ weight ] of my-links ] of node 0  / count nodes ) 5
1
1
11

MONITOR
197
377
272
422
day
monit-day
17
1
11

@#$#@#$#@
## WHAT IS IT?

This agent-based model explores network analysis in the context of GIS by exploiting real-case data.

We model as a directed network four kinds of company relations focused on a Small-Medium Enterprise in Italy (henceforth Ego): 
- Ego to customers
- Suppliers to Ego
- Ego to Subcontractors
- Subcontractors to Ego

We create a node for each company involved. A link to/from Ego can be weighted for the number of item in the order. 

## HOW IT WORKS

Data come from CSV files having in each row an order including the data of arrival, latitude and longitude coordinates, the number of items (weight) of the order and the number of days to next one (delta).

In the model, orders appear on the GIS map at the corresponding location and time. Each node includes variables related to the order as well as a link to Ego. 

## HOW TO USE IT

In the Interface, six sections allow to perform different analysis.

1. "Setup and create Company" button allows the creation of the world (GIS), with the first node corresponding to the Main Company colored in green.

2. Button "Create Nodes and Edges for:" allows to place on the map links between Ego and companies depending on the kind of order:
- to Customers (shipping order of prodcts, from Ego)
- from Vendors (purchase order for products, from suppliers to Ego)
- from and to Subcontractors (both directions are possible, from and to Ego)

Monitors indicates number of nodes and edges of related star-network.

3. Compute Network Metrics

Visualize in an output area other information (e.g. network degree, dentity).

4. Data analysis

Monitors count the number of company linked to Ego.

5. Temporal Network

Visualize the dynamic temporal network between ego and other companies, deoending on four type of orders. A monitor describes the Average Degree oìdynamically changing.

6. Visualize Networks

Open the star-network of our Company setting weight of links depending


## CREDITS AND REFERENCES

Example of NetLogo with Network Analysis and GIS
Emilio Sulis, Kuldar Taveter, ABforBPM Springer book. 
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

factory
false
0
Rectangle -7500403 true true 76 194 285 270
Rectangle -7500403 true true 36 95 59 231
Rectangle -16777216 true false 90 210 270 240
Line -7500403 true 90 195 90 255
Line -7500403 true 120 195 120 255
Line -7500403 true 150 195 150 240
Line -7500403 true 180 195 180 255
Line -7500403 true 210 210 210 240
Line -7500403 true 240 210 240 240
Line -7500403 true 90 225 270 225
Circle -1 true false 37 73 32
Circle -1 true false 55 38 54
Circle -1 true false 96 21 42
Circle -1 true false 105 40 32
Circle -1 true false 129 19 42
Rectangle -7500403 true true 14 228 78 270

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

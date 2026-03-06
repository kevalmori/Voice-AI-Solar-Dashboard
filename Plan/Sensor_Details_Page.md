# Sensor Details Page

## Route

/sensors/:sensor_id

Example

/sensors/CANT_RADIATION_1

---

# UI Components

Sensor Name
Sensor Category
Live Value
Last Updated Time
Graph
Date Selector

---

# Get Sensor Name

Selector

h2.MuiTypography-h2

Function

get_sensor_name()

JS

document.querySelector("h2.MuiTypography-h2").innerText

---

# Get Sensor Category

Selector

h6.MuiTypography-h6

Function

get_sensor_category()

JS

document.querySelector("h6.MuiTypography-h6").innerText

---

# Get Sensor Value

Selector

h5.MuiTypography-h5

Example

-- W/m²

Function

get_sensor_value()

JS

document.querySelector("h5.MuiTypography-h5").innerText

---

# Get Last Update Time

Selector

.css-1idzl3r

Function

get_sensor_last_update()

JS

document.querySelector(".css-1idzl3r").innerText

---

# Change Graph Date

Selector

.datepicker-input

Function

set_graph_date(date)

Example

set_graph_date("04/03/2026")

JS

document.querySelector(".datepicker-input").value="04/03/2026"

---

# Graph Element

Selector

canvas

Graph type

Irradiance Live Trend

---

# Recommended Approach

Do not scrape graph data.

Instead call backend API used by graph.

Example

/api/sensor-data?sensor_id=CANT_RADIATION_1&date=2026-03-04

Function

get_sensor_graph_data(sensor_id,date)
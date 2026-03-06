# Sensors Page Documentation

## Route
/sensors

## Purpose

Displays all available sensors in the system including:

- Radiation sensors
- Temperature sensors
- MFM sensors

---

# Table Structure

Columns:

Device Name
Category
Manufacturer
Created On

Selector

tbody tr

---

# Search Sensor

Selector

input[placeholder="Search inverters..."]

Function

search_sensor(name)

Example

search_sensor("CANT_TEMP_1")

JS

document.querySelector('input[placeholder="Search inverters..."]').value="CANT_TEMP_1"

---

# Open Sensor

Selector

tbody tr

Function

open_sensor(name)

JS

[...document.querySelectorAll("tbody tr")]
.find(r=>r.innerText.includes(name))
.click()

---

# Open Sensor By Index

Function

open_sensor_by_index(index)

JS

document.querySelectorAll("tbody tr")[index].click()

---

# Filter Sensors

Available tabs:

All
WMS
Temperature
MFM

Selector

[role="tab"]

Function

filter_sensors(type)

Example

filter_sensors("temperature")

JS

[...document.querySelectorAll('[role="tab"]')]
.find(t=>t.innerText.toLowerCase().includes(type))
.click()

---

# Get Sensors List

Function

get_all_sensors()

Returns

[
{
name:"CANT_RADIATION_1",
category:"WMS"
},
{
name:"CANT_TEMP_1",
category:"Temperature"
}
]
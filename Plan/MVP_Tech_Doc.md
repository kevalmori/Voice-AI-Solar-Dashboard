# MVP Technical Documentation

## MVP Goal

Create a working prototype where AI can:

1 open pages
2 interact with tables
3 read values
4 control graphs

---

## Features for MVP

Open dashboard

Open sensors

Search sensor

Open sensor

Read sensor value

Change graph date

---

## LLM Tools

Navigation

open_dashboard()

open_sensors()

open_plants()

open_inverters()

---

Sensors

search_sensor(name)

open_sensor(name)

open_sensor_by_index(index)

filter_sensors(type)

get_all_sensors()

---

Sensor Details

get_sensor_name()

get_sensor_category()

get_sensor_value()

get_sensor_last_update()

set_graph_date(date)

change_graph_mode(mode)

---

## Example Execution

User:

show radiation sensor

LLM plan:

open_sensors()

search_sensor("CANT_RADIATION_1")

open_sensor("CANT_RADIATION_1")

get_sensor_value()

---

## Suggested Stack

Mobile App

React Native

AI

OpenAI GPT API

Automation

WebView + JavaScript bridge
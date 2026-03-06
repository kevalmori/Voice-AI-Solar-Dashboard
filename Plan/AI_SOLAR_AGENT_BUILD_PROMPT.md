# AI Solar Monitoring Web Control App

## Project Goal

Build a mobile application that allows users to control a solar monitoring dashboard using natural language.

Users should be able to type commands such as:

"open sensors"

"show radiation sensor"

"show yesterday irradiance graph"

The app will interpret these commands using an LLM and execute them on the website inside a WebView.

---

# System Overview

User
↓
Mobile App
↓
LLM Agent
↓
Tool Selection
↓
WebView Controller
↓
Website DOM / API

---

# Mobile App Requirements

Create a mobile application using one of the following:

Preferred:
React Native

Alternative:
Flutter

The app must contain:

1 Chat Interface
2 WebView to load dashboard
3 LLM communication layer
4 Tool execution system
5 Suggestion engine

---

# Website

Solar monitoring dashboard.

Pages available:

/dashboard
/plants
/inverters
/slms
/sensors
/sensors/:sensor_id

The website is built using:

React
Material UI
Vite
SPA routing

---

# Mobile App Structure

src/

components/
ChatUI
WebViewContainer

services/
LLMService
ToolExecutor

tools/
navigationTools
sensorTools

utils/
domExecutor

App.js

---

# WebView Controller

Load website inside WebView.

Example:

webview.loadUrl("/dashboard")

Execute JavaScript:

webview.injectJavaScript()

Example:

document.querySelector("tbody tr").click()

---

# LLM Agent

The LLM receives user input and decides which tool to call.

Example:

User:
show temperature sensors

LLM Output:

{
 "tool": "filter_sensors",
 "parameters": {
   "type": "temperature"
 }
}

---

# Tool System

Tools are functions that perform actions inside the website.

---

## Navigation Tools

open_dashboard()

open_plants()

open_inverters()

open_slms()

open_sensors()

Implementation:

webview.loadUrl("/dashboard")

---

## Sensors Page Tools

search_sensor(name)

open_sensor(name)

open_sensor_by_index(index)

filter_sensors(type)

get_all_sensors()

Example JS:

document.querySelector('input[placeholder="Search inverters..."]').value=name

---

## Sensor Details Tools

get_sensor_name()

get_sensor_category()

get_sensor_value()

get_sensor_last_update()

set_graph_date(date)

change_graph_mode(mode)

edit_sensor()

Example:

document.querySelector(".datepicker-input").value="04/03/2026"

---

# Graph Handling

Graphs are rendered using canvas.

Do NOT scrape canvas.

Instead call backend API used by graph.

Example API:

/api/sensor-data?sensor_id=CANT_RADIATION_1&date=2026-03-04

Tool:

get_sensor_graph_data(sensor_id,date)

---

# LLM Prompt

System prompt for AI:

You are an AI agent that controls a solar monitoring dashboard.

Your job is to interpret user commands and choose the correct tool.

Available tools:

open_dashboard
open_plants
open_inverters
open_slms
open_sensors

search_sensor
open_sensor
filter_sensors

get_sensor_value
get_sensor_name
set_graph_date

Always respond using tool calls.

---

# Example Interaction

User:

show radiation sensor value

LLM plan:

open_sensors()

search_sensor("CANT_RADIATION_1")

open_sensor("CANT_RADIATION_1")

get_sensor_value()

---

# Suggestion Engine

After completing a task the AI should suggest next actions.

Example:

You opened the radiation sensor.

Suggestions:
- Show graph
- Show yesterday data
- Compare with temperature sensor

---

# Tech Stack

Mobile

React Native

AI

OpenAI API

Automation

WebView + JavaScript bridge

Backend

Existing solar monitoring APIs

---

# MVP Features

User chat input

AI interpretation

Navigation automation

Sensor search

Sensor data reading

Graph date change

---

# Future Features

Voice control

Predictive suggestions

AI troubleshooting

Solar performance analysis

Multi-plant management

---

# Final Goal

Create an intelligent assistant that allows users to control the solar monitoring dashboard entirely through natural language.
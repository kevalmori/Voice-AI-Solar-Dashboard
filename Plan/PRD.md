# Product Requirement Document

## Product Name
AI Solar Dashboard Assistant

---

## Problem

Solar monitoring dashboards are complex and require manual navigation.

Users should be able to control the system using natural language.

Example:

"Open sensors"

"Show radiation sensor"

"Show yesterday graph"

---

## Goal

Build a mobile app that:

1 understands user commands
2 navigates the website automatically
3 executes tasks inside WebView

---

## Key Features

### Natural Language Control

User can type:

show sensors

open inverter

show irradiance graph

---

### Smart Navigation

LLM determines the correct page.

Example:

User:
open sensors

App:
webview.loadUrl("/sensors")

---

### Data Interaction

AI can:

search sensors

filter sensors

read values

change graph date

---

### Suggestions

After completing a task AI suggests next action.

Example:

You opened the radiation sensor.
Would you like to see the graph?
# AI Web Control Mobile App - Architecture

## Overview
This system allows a user to control a solar monitoring website using natural language.

User speaks or types a command → LLM interprets → mobile app performs actions inside WebView.

---

## Architecture Flow

User
↓
Mobile App (React Native / Flutter)
↓
LLM Agent
↓
Tool Selection
↓
WebView Controller
↓
DOM / API Execution
↓
Website Response

---

## Core Components

### 1 Mobile App
Responsibilities:
- Capture user input
- Send request to LLM
- Execute tool calls
- Control WebView

Tech options:
- React Native
- Flutter

---

### 2 LLM Agent

Responsibilities:
- Interpret user intent
- Decide which tool to call
- Generate structured response

Example:

User:
open temperature sensors

LLM Output:

{
  "tool": "filter_sensors",
  "parameters": {
    "type": "temperature"
  }
}

---

### 3 Tool Layer

Tools are functions the AI can call.

Example:

open_dashboard()

open_sensors()

search_sensor(name)

open_sensor(name)

get_sensor_value()

---

### 4 WebView Controller

Executes JavaScript inside the webpage.

Example:

webview.injectJavaScript(`
document.querySelector("tbody tr").click()
`)
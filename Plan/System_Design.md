# System Design

## Frontend

Mobile App

Framework options:

React Native
Flutter

Main Components:

Chat Interface
WebView
Tool Executor
LLM Connector

---

## WebView Layer

Loads the solar dashboard.

Example:

webview.loadUrl("/dashboard")

JavaScript bridge executes DOM actions.

Example:

document.querySelector(".datepicker-input").value="04/03/2026"

---

## AI Layer

LLM with tool calling.

Options:

OpenAI GPT
Claude
DeepSeek
Llama

---

## Tool Execution

Example flow:

User:
show temperature sensors

LLM:

filter_sensors("temperature")

App executes:

document.querySelector('[role="tab"]').click()

---

## Data Layer

Graph data should be fetched using backend APIs instead of scraping canvas.
# AI Website Control System

## Overview

The system allows a user to control a web dashboard using natural language commands.

User commands are interpreted by an LLM which calls automation tools.

---

# Architecture

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
DOM Execution

---

# Example Flow

User:

show temperature sensors

LLM:

{
 "tool":"filter_sensors",
 "parameters":{
   "type":"temperature"
 }
}

Mobile App executes

WebView JS

---

# Technology Stack

Mobile App
Flutter

AI Layer
OpenAI / Claude / Llama

Automation
WebView JS Bridge

Backend
Existing solar monitoring APIs
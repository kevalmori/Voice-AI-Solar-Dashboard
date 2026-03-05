# Architecture

## Overview
This project is an AI-powered mobile application that allows users to control and navigate websites using natural language commands.

Example:
User: "Open Flipkart and show phones under 20000"

The system interprets the request using an LLM and performs actions automatically.

---

## High-Level Architecture

User
↓
Mobile App
↓
Backend API
↓
LLM Engine
↓
Automation Engine
↓
Website (WebView)

---

## Components

### Mobile App
Responsible for:
- Taking user commands
- Displaying websites
- Showing suggestions
- Executing automation scripts

Recommended framework:
- Flutter

---

### Backend API
Responsibilities:
- Process user commands
- Communicate with LLM
- Generate automation steps

Recommended stack:
- Node.js
- Python

---

### LLM Layer
Responsibilities:
- Understand user intent
- Convert commands to structured tasks
- Suggest next actions

Examples:
- OpenAI
- Google Gemini

---

### Automation Engine
Responsible for interacting with the webpage.

Actions include:
- clicking buttons
- entering text
- applying filters
- navigating pages

Tools:
- JavaScript DOM automation
- Puppeteer (optional)

---

### Suggestion Engine
After completing tasks:
- analyze page state
- generate possible next actions
- show suggestions to user
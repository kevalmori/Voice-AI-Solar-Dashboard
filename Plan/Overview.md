# AI Web Navigator – Full Project Documentation

## 1. Project Overview

AI Web Navigator is a mobile application that allows users to control and navigate a website using natural language commands.

Instead of manually navigating through menus and buttons, the user simply describes what they want, and the system performs the actions automatically.

Example interaction:

User:
"Show solar panels under ₹20000"

System actions:
1. Understand the user intent
2. Open the correct webpage
3. Perform actions like filtering or sorting
4. Suggest next actions for the user

The website will be displayed inside a mobile app using WebView.

---

# 2. Core Idea

The system works using an LLM (Large Language Model) that interprets user instructions and decides what actions the app should perform.

The LLM does NOT directly control the browser.

Instead, it selects from predefined functions that the app can execute.

This architecture is called **LLM Tool / Function Calling**.

---

# 3. System Architecture

User
↓
Mobile App
↓
LLM Planner
↓
Function Router
↓
WebView Controller
↓
Website
↓
Suggestion Engine

---

# 4. Technology Stack

Mobile App
Flutter

Backend
Node.js / Python

AI Model
LLM API

Website Viewer
WebView

Automation
JavaScript DOM Manipulation

---

# 5. System Workflow

## Step 1 – User Input

User provides a command using text or voice.

Example:

"Open solar products"

or

"Show cheapest solar panel"

---

## Step 2 – LLM Interprets Intent

The LLM converts the command into structured instructions.

Example response:

{
"page": "solar_products",
"tasks": [
{"action": "filter", "type": "panel"},
{"action": "sort", "type": "price"}
]
}

---

## Step 3 – Open Page in WebView

The mobile app loads the correct page.

Example:

https://website.com/solar-products

---

## Step 4 – LLM Executes Subtasks

After the page loads, the LLM decides which function to call.

Example functions:

filter_products(type)

sort_products(type)

open_product(index)

scroll_page()

click_button(selector)

---

## Step 5 – Automation Engine Executes Functions

Each function triggers JavaScript code inside WebView.

Example:

document.querySelector(".product-card").click()

or

document.querySelector("#price-filter").value = "20000"

---

## Step 6 – Page Updates

The website responds to the actions.

Products are filtered or sorted.

---

## Step 7 – Generate Suggestions

After completing the action, the system asks the LLM for next suggestions.

Example suggestions:

Compare top products

View installation service

Contact support

Calculate savings

---

## Step 8 – Continuous Interaction Loop

User → Command

AI → Execute task

AI → Suggest next actions

User → Choose next action

Loop continues.

---

# 6. Function-Based Control System

The LLM cannot run arbitrary code.

It can only call predefined functions.

Example functions:

open_page(page_name)

search_products(query)

open_product(index)

filter_products(filter_type)

sort_products(sort_type)

scroll_page()

go_back()

click_element(selector)

---

Example LLM response:

{
"function_call": "open_page",
"arguments": {
"page_name": "solar_products"
}
}

The app executes this function.

---

# 7. Page Navigation Map

The system needs a list of website pages.

Example:

home → /

about → /about

solar_products → /solar-products

services → /services

contact → /contact

This allows the LLM to select correct pages.

---

# 8. DOM Interaction Strategy

When the website loads, the automation engine interacts with the DOM.

Example:

Select product cards

document.querySelectorAll(".product-card")

Open product by index

products[5].click()

This allows the system to open items even if their URLs are dynamic.

---

# 9. Suggestion Engine

After every action, the system generates suggestions.

Example:

What would you like to do next?

• Compare products
• Filter by brand
• See installation services
• Contact company

These suggestions are displayed as buttons in the app.

---

# 10. UI Layout

The mobile app will have three main sections.

Top Section
User command input

Middle Section
WebView showing the website

Bottom Section
AI suggestions

Layout Example:

--------------------------------
Command Input
--------------------------------

Website WebView

--------------------------------
AI Suggestions
--------------------------------

---

# 11. Example Full Interaction

User:
"Show solar panels"

System:
Open solar products page

User:
"Show cheapest one"

System:
Sort by price

User:
"Open the third one"

System:
Click product index 3

User:
"Compare with second one"

System:
Open comparison view

---

# 12. Future Improvements

Voice commands

Advanced automation

AI page understanding

Smart product comparison

Multi-website support

AI shopping assistant

---

# 13. Final Goal

The final system should function like an **AI agent that can operate websites for the user**.

The user simply describes what they want.

The AI navigates the website and performs the required actions automatically.

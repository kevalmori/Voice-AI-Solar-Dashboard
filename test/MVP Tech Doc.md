# MVP Technical Documentation

## Goal
Create a Minimum Viable Product that allows users to control websites using natural language.

---

## MVP Features

### 1. Command Input
Users enter a command.

Example:
Search phones under 20000 on Flipkart

---

### 2. Intent Detection
LLM converts text into structured commands.

Example output:

{
website: "flipkart",
search: "phones",
price_max: 20000
}

---

### 3. Website Loading
The application loads the website inside a WebView.

Example:
https://www.flipkart.com

---

### 4. Automation Execution
JavaScript executes tasks inside the page.

Examples:
- enter search keyword
- click buttons
- apply filters

---

### 5. AI Suggestions
After completing an action the system suggests next steps.

Examples:
- sort by rating
- filter by brand
- open product

# System Design

## System Workflow

User Input
↓
Mobile App
↓
Backend API
↓
LLM Processing
↓
Automation Plan
↓
Automation Engine
↓
Website Interaction
↓
Suggestion Engine
↓
User Feedback Loop

---

## Detailed Flow

### Step 1 — User Command
User enters a command.

Example:
Find phones under 20000

---

### Step 2 — Intent Parsing
LLM extracts key information.

Example:

website: flipkart  
search: phones  
price_max: 20000

---

### Step 3 — Action Planning
The system generates automation steps.

Example:
1. open website
2. search product
3. apply price filter

---

### Step 4 — Automation Execution
JavaScript interacts with the page.

Example actions:
- fill search input
- click search button
- select price filter

---

### Step 5 — Page Analysis
The system checks the current page state.

---

### Step 6 — Suggestion Generation
LLM suggests next possible actions.

Example:
Sort by rating  
Filter by Samsung  
Show best deals

---

### Step 7 — User Decision
User selects the next action and the cycle continues.
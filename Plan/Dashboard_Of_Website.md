# Dashboard Page Documentation

## Page Route
/dashboard

## Framework
React + Material UI + Vite

## Purpose
Displays real-time overview of the solar monitoring system including:
- Live system metrics
- Alerts
- Navigation to other modules

---

# UI Structure

## Top Header

Elements:

- Current Time
- User Profile
- Alerts Button

Selectors:

Time
h6.MuiTypography-h6

User
h6.MuiTypography-subtitle1

Alerts
button:contains("Alerts")

---

# Sidebar Navigation

Main navigation items detected:

Dashboard
Plants
Inverters
SLMs
Sensors
Logout

Selector:

.MuiListItemButton-root

---

# Navigation Functions (LLM Tools)

open_dashboard()

JS

webview.loadUrl("/dashboard")

---

# LLM Interaction Example

User:
show dashboard

LLM plan:

open_dashboard()

---

# Data Sources

Dashboard uses API services from:

rest-api-services-Bi1eMUcz.js

Graph rendering:

common-graph-Db59VhJN.js

---

# Automation Notes

The dashboard page is a SPA component.  
Navigation should use route loading instead of DOM clicking.

Preferred method:

webview.loadUrl("/dashboard")

instead of clicking sidebar.
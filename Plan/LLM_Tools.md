# LLM Tool Specification

The AI agent controls the website using tool calls.

---

# Navigation Tools

open_dashboard()

open_plants()

open_inverters()

open_slms()

open_sensors()

---

# Sensor Page Tools

search_sensor(name)

open_sensor(name)

open_sensor_by_index(index)

filter_sensors(type)

get_all_sensors()

---

# Sensor Details Tools

get_sensor_name()

get_sensor_category()

get_sensor_value()

get_sensor_last_update()

set_graph_date(date)

change_graph_mode(mode)

get_sensor_graph_data(sensor_id,date)

edit_sensor()
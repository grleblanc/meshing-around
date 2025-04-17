import paho.mqtt.client as mqtt
import json
import sqlite3
import os
from time import sleep
import requests

# --- Configuration ---
MQTT_BROKER = "10.250.1.111"
MQTT_PORT = 1883
MQTT_TOPIC = "meshtastic/packets"  # Subscribe to all topics by default
MQTT_USERNAME = ""
MQTT_PASSWORD = ""
DATABASE_FILE = "/data/data.db"
TABLE_NAME = "mqtt_data"


# --- Database Initialization ---
def create_table():
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    cursor.execute(f"""
        CREATE TABLE IF NOT EXISTS {TABLE_NAME} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            topic TEXT,
            payload TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    conn.close()

# --- MQTT Callbacks ---
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print(f"Connected to MQTT Broker: {MQTT_BROKER}:{MQTT_PORT}")
        client.subscribe(MQTT_TOPIC)
        print(f"Subscribed to topic: {MQTT_TOPIC}")
    else:
        print(f"Failed to connect, return code {rc}")

def send_push_notification(url):
    try:
        # Simulate sending a push notification
        print(f"Sending push notification to {url}")
        requests.get(url)
        # Here you would implement the actual HTTP request to send the notification
    except Exception as e:
        print(f"Error sending push notification: {e}")
        
def on_message(client, userdata, msg):
    try:
        payload_dict = json.loads(msg.payload.decode())
        print(f"Received message on topic '{msg.topic}': {payload_dict}")
        save_to_database(msg.topic, json.dumps(payload_dict))
        
    except json.JSONDecodeError:
        print(f"Error decoding JSON from topic '{msg.topic}': {msg.payload.decode()}")
    except Exception as e:
        print(f"An error occurred processing message: {e}")

# --- Database Interaction ---
def save_to_database(topic, payload):
    try:
        conn = sqlite3.connect(DATABASE_FILE)
        cursor = conn.cursor()
        cursor.execute(f"INSERT INTO {TABLE_NAME} (topic, payload) VALUES (?, ?)", (topic, payload))
        conn.commit()
        conn.close()
        print(f"Data saved to database for topic: {topic}")
    except sqlite3.Error as e:
        print(f"Database error: {e}")

# --- Main Execution ---
if __name__ == "__main__":
    create_table()

    client = mqtt.Client()

    if MQTT_USERNAME and MQTT_PASSWORD:
        client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)

    client.on_connect = on_connect
    client.on_message = on_message

    # Implement retry logic for connection
    retry_delay = 5
    max_retries = 5
    retries = 0
    while retries < max_retries:
        try:
            client.connect(MQTT_BROKER, MQTT_PORT)
            client.loop_forever()
            break  # Exit the loop if connected
        except ConnectionRefusedError:
            print(f"Connection refused. Retrying in {retry_delay} seconds ({retries + 1}/{max_retries})...")
            sleep(retry_delay)
            retries += 1
        except Exception as e:
            print(f"An unexpected error occurred: {e}. Retrying...")
            sleep(retry_delay)
            retries += 1

    if retries == max_retries:
        print("Failed to connect to MQTT broker after multiple retries. Exiting.")
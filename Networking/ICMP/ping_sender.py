#!/usr/bin/env python3
from scapy.all import *
import time

# The IP of the Windows client that we want to ping
TARGET_IP = "192.168.0.12"

def main():
    print(f"Starting to send pings to {TARGET_IP}...")
    while True:
        # Create an ICMP echo request
        pkt = IP(dst=TARGET_IP)/ICMP()

        # Send the packet. send() is used for raw packets. It's a one-shot send.
        send(pkt, verbose=False)

        # Wait a second before sending the next ping
        time.sleep(1)

if __name__ == "__main__":
    main()

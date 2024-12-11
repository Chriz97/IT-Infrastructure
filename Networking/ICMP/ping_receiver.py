#!/usr/bin/env python3
from scapy.all import *

# This should be the IP of the Windows client machine
MY_IP = "192.168.0.12"


def handle_packet(pkt):
    # Check if the packet has ICMP layer
    if pkt.haslayer(ICMP):
        icmp_layer = pkt.getlayer(ICMP)
        ip_layer = pkt.getlayer(IP)

        # Check if it's an echo request (type=8 is ICMP echo request)
        if icmp_layer.type == 8:
            # The packet is an incoming ping. Print a message.
            print(f"Ping received from {ip_layer.src}")


def main():
    print(f"Listening for pings on {MY_IP}...")
    # Sniff ICMP packets destined to our IP
    sniff(filter=f"icmp and host {MY_IP}", prn=handle_packet, store=False)


if __name__ == "__main__":
    main()

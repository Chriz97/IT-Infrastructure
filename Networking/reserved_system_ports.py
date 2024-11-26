import socket

def list_reserved_ports():
    # Ports range from 0 to 1023. These are the well-known or system ports.
    reserved_ports = range(0, 1024)
    port_services = []

    for port in reserved_ports:
        try:
            # Get the service name for the port using socket
            service_name = socket.getservbyport(port)
            port_services.append((port, service_name))
        except OSError:
            # Port may not have a known service
            port_services.append((port, "Unknown"))

    return port_services

def display_ports(ports):
    print(f"{'Port':<10}{'Service':<20}")
    print("-" * 30)
    for port, service in ports:
        print(f"{port:<10}{service:<20}")

if __name__ == "__main__":
    reserved_ports = list_reserved_ports()
    display_ports(reserved_ports)

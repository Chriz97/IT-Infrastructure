import socketserver


# Define a handler for incoming syslog messages
class SyslogUDPHandler(socketserver.BaseRequestHandler):
    def handle(self):
        data = self.request[0].strip()
        socket = self.request[1]
        message = data.decode('utf-8')

        # Print the message to the console
        print(f"Received message from {self.client_address[0]}: {message}")

        # Append the message to a log file
        with open("syslog_received.log", "a") as log_file:
            log_file.write(f"{self.client_address[0]}: {message}\n")


if __name__ == "__main__":
    HOST, PORT = "0.0.0.0", 514  # Listen on all interfaces, port 514
    print(f"Starting Syslog server on {HOST}:{PORT}")

    # Create a server instance
    with socketserver.UDPServer((HOST, PORT), SyslogUDPHandler) as server:
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nServer is shutting down.")
            server.shutdown()


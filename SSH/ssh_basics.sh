# Connect to a Server via SSH
ssh username@192.168.56.101

# Connect to a Server Using a Specific Private Key
ssh -i /path/to/private_key username@192.168.56.101

# Run a Single Command on a Remote Server
ssh username@192.168.56.101 'ls -la'

# Generate an SSH Key Pair
ssh-keygen -t rsa -b 2048

# Upload Public Key to a Remote Server
ssh-copy-id username@192.168.56.101

# Copy a File from Local to Remote
scp /path/to/local_file username@192.168.56.101:/path/to/remote_directory

# Copy a File from Remote to Local
scp username@192.168.56.101:/path/to/remote_file /path/to/local_directory

# Copy a Directory from Local to Remote
scp -r /path/to/local_directory username@192.168.56.101:/path/to/remote_directory

# Debug SSH Connection Issues
ssh -v username@192.168.56.101

# Use a Non-Default Port for SSH
ssh -p 2222 username@192.168.56.101

# Forward a Remote Port to Local
ssh -L 8080:localhost:80 username@192.168.56.101

# Forward a Local Port to Remote
ssh -R 9090:localhost:3306 username@192.168.56.101

# Copy an SSH Key to Multiple Servers
for server in server1 server2 server3; do ssh-copy-id username@$server; done

# Reuse SSH Connections (Connection Multiplexing)
echo "ControlMaster auto" >> ~/.ssh/config
echo "ControlPath ~/.ssh/sockets/%r@%h:%p" >> ~/.ssh/config
echo "ControlPersist 600" >> ~/.ssh/config

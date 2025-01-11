# Certificate Management Script
# All commands and configurations were tested on Fedora 41 Workstation.

# Step 1: Check Certificate Expiration
# To check the expiration date of a certificate:
openssl x509 -in server_cert.pem -noout -enddate

# To view both the start and end dates of the certificate:
openssl x509 -in server_cert.pem -noout -startdate -enddate

# To see detailed certificate information:
openssl x509 -in server_cert.pem -text -noout


# Step 2: Back Up the Current Certificate and Key
# Before making any changes, back up your existing certificate and private key:
cp server_cert.pem server_cert_backup.pem
cp server_key.pem server_key_backup.pem


# Step 3: Renew the Certificate
# Option 1: Renew Using the Existing Private Key
# If the private key is secure and valid, generate a new self-signed certificate:
openssl req -new -key server_key.pem -x509 -days 365 -out server_cert.pem

# Option 2: Generate a New Private Key and Certificate
# If the private key is compromised or needs to be replaced:
openssl req -newkey rsa:2048 -nodes -keyout server_key.pem -x509 -days 365 -out server_cert.pem

# Option 3: Use a Different Algorithm (Elliptic Curve Cryptography)
# To generate a new certificate with an elliptic curve key:
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout server_key.pem -x509 -days 365 -out server_cert.pem


# Step 4: Verify the Renewed Certificate
# Check the validity period of the new certificate:
openssl x509 -in server_cert.pem -noout -startdate -enddate


# Step 5: Replace the Old Certificate
# Replace the old certificate and key in your application or server configuration.
# Example: For a Python QUIC server:
# configuration.load_cert_chain("server_cert.pem", "server_key.pem")


# Step 6: Restart Your Server
# Restart the server to load the new certificate.
systemctl restart your_service_name.service


# Step 7: Automate Renewal (Optional)
# Automate renewal of self-signed certificates with a cron job or systemd timer.
# Example cron job to renew a self-signed certificate every 11 months:
# 0 0 1 */11 * openssl req -new -key server_key.pem -x509 -days 365 -out server_cert.pem

# For publicly trusted certificates (e.g., Let's Encrypt), use Certbot:
# Install Certbot:
sudo dnf install certbot
# Generate and install certificates:
sudo certbot certonly --standalone -d yourdomain.com
# Set up automatic renewal:
sudo certbot renew --dry-run

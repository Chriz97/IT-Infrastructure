from ipwhois import IPWhois
import socket


def resolve_ip(ip_address):
    try:
        # Perform reverse DNS lookup
        hostname = socket.gethostbyaddr(ip_address)[0]
    except socket.herror:
        hostname = "Hostname could not be resolved"

    try:
        # Perform IP WHOIS lookup
        obj = IPWhois(ip_address)
        whois_info = obj.lookup_rdap()

        # Extract detailed information like ASN, Contacts, Cidr
        network_info = whois_info.get("network", {})
        asn_info = {
            "asn": whois_info.get("asn"),
            "asn_description": whois_info.get("asn_description"),
            "asn_country_code": whois_info.get("asn_country_code")
        }

        details = {
            "hostname": hostname,
            "network_name": network_info.get("name", "N/A"),
            "cidr": network_info.get("cidr", "N/A"),
            "asn": asn_info.get("asn", "N/A"),
            "asn_description": asn_info.get("asn_description", "N/A"),
            "asn_country": asn_info.get("asn_country_code", "N/A"),
            "contacts": whois_info.get("entities", "N/A")
        }
    except Exception as e:
        details = {"error": f"WHOIS lookup failed: {e}"}

    return details


# Input: IP address
ip = "45.57.17.164"
resolved_info = resolve_ip(ip)

# Print the detailed information
for key, value in resolved_info.items():
    print(f"{key.capitalize()}: {value}")

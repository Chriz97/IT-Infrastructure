import ssl
import socket
import certifi
import hashlib
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization

def get_ssl_info_and_pubkey_hash(hostname):
    context = ssl.create_default_context(cafile=certifi.where())
    with socket.create_connection((hostname, 443)) as sock:
        with context.wrap_socket(sock, server_hostname=hostname) as sslsock:
            cert_bin = sslsock.getpeercert(binary_form=True)  # Get DER-encoded certificate
            cert = x509.load_der_x509_certificate(cert_bin, default_backend())  # Use cryptography to parse

    # Certificate Details
    subject = cert.subject
    issuer = cert.issuer

    print("-------Certificate Subject-------")
    for name in subject:
        print(f"{name.oid._name}: {name.value}")

    print("\n-------Certificate Issuer-------")
    for name in issuer:
        print(f"{name.oid._name}: {name.value}")

    print("\n-------Other Details-------")
    print(f"Version: {cert.version}")
    print(f"Not Before (UTC): {cert.not_valid_before_utc}")
    print(f"Not After (UTC): {cert.not_valid_after_utc}")

    # Certificate SHA-256 Fingerprint
    thumb_sha256 = hashlib.sha256(cert_bin).hexdigest().upper()
    print(f"\n-------SHA-256 Fingerprint of Certificate-------")
    print(f"SHA-256: {thumb_sha256}")

    # Public Key SHA-256 Hash
    pub_key_bin = cert.public_key().public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    pub_key_sha256 = hashlib.sha256(pub_key_bin).hexdigest().upper()
    print(f"\n-------SHA-256 Hash of Public Key-------")
    print(f"SHA-256: {pub_key_sha256}")

hostnames = ("www.google.com", "www.amazon.com", "www.uni.li", "www.twitch.tv")
for hostname in hostnames:
    print(f"\nCertificate and Public Key Details for: {hostname}")
    get_ssl_info_and_pubkey_hash(hostname)

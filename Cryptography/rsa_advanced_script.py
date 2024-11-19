from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives import serialization

# Generate RSA keys
def generate_keys():
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
    )
    public_key = private_key.public_key()
    return private_key, public_key

# Save keys to files
def save_keys(private_key, public_key):
    # Save private key
    with open("private_key.pem", "wb") as private_file:
        private_file.write(
            private_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption()
            )
        )

    # Save public key
    with open("public_key.pem", "wb") as public_file:
        public_file.write(
            public_key.public_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PublicFormat.SubjectPublicKeyInfo
            )
        )

# Load keys from files
def load_keys():
    with open("private_key.pem", "rb") as private_file:
        private_key = serialization.load_pem_private_key(
            private_file.read(),
            password=None,
        )

    with open("public_key.pem", "rb") as public_file:
        public_key = serialization.load_pem_public_key(
            public_file.read(),
        )

    return private_key, public_key

# Encrypt a message
def encrypt_message(message, public_key):
    ciphertext = public_key.encrypt(
        message.encode(),
        padding.OAEP(
            mgf=padding.MGF1(algorithm=hashes.SHA256()),
            algorithm=hashes.SHA256(),
            label=None
        )
    )
    return ciphertext

# Decrypt a message
def decrypt_message(ciphertext, private_key):
    plaintext = private_key.decrypt(
        ciphertext,
        padding.OAEP(
            mgf=padding.MGF1(algorithm=hashes.SHA256()),
            algorithm=hashes.SHA256(),
            label=None
        )
    )
    return plaintext.decode()

# Main workflow
if __name__ == "__main__":
    # Step 1: Generate keys
    private_key, public_key = generate_keys()

    # Step 2: Save keys to files
    save_keys(private_key, public_key)

    # Step 3: Load keys (for demonstration purposes)
    private_key, public_key = load_keys()

    # Step 4: Encrypt a message
    message = "This is a secret message!"
    print(f"Original message: {message}")
    ciphertext = encrypt_message(message, public_key)
    print(f"Encrypted message: {ciphertext}")

    # Step 5: Decrypt the message
    decrypted_message = decrypt_message(ciphertext, private_key)
    print(f"Decrypted message: {decrypted_message}")

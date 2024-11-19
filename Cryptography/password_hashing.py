import hashlib
import os
import bcrypt

# SHA-256 Example with Salt
plaintext = "password123"

# Generate a random salt
salt = os.urandom(16)

# Combine salt and plaintext
salted_plaintext = salt+ plaintext.encode()

# Calculate SHA-256 hash with salt
sha256_hash = hashlib.sha256(salted_plaintext).hexdigest()

print("SHA-256 hash with salt:", sha256_hash)

# bcrypt Example with Salt
bcrypt_salt = bcrypt.gensalt()

# Generate bcrypt hash with salt
bcrypt_hash = bcrypt.hashpw(plaintext.encode(), bcrypt_salt)

print("bcrypt hash with salt:", bcrypt_hash.decode())

# Verify bcrypt hash with plaintext and salt
is_matched = bcrypt.checkpw(plaintext.encode(), bcrypt_hash)

print("bcrypt hash matches plaintext:", is_matched)

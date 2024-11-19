# Source: https://support.google.com/chrome/a/answer/9696904?hl=en

import hashlib
import os

def hash_password_scrypt(password):
    """
    Hashes a password using scrypt and truncates the result to 37 bits.
    """
    # Generate a secure random salt
    salt = os.urandom(16)

    # Use scrypt to hash the password
    hashed_password = hashlib.scrypt(
        password.encode(),  # Convert password to bytes
        salt=salt,          # Use the generated salt
        n=16384,            # CPU/memory cost parameter
        r=8,                # Block size parameter
        p=1                 # Parallelization parameter
    )

    # Truncate the hash to 37 bits (5 bytes with 5 bits in the last byte)
    # Convert the hash to an integer for truncation
    hash_as_int = int.from_bytes(hashed_password, "big")
    truncated_hash = hash_as_int & ((1 << 37) - 1)  # Mask to get the lowest 37 bits

    return truncated_hash, salt


def verify_password_scrypt(password, salt, stored_truncated_hash):
    """
    Verifies if a password matches the stored truncated scrypt hash.
    """
    # Hash the input password with the provided salt
    hashed_password = hashlib.scrypt(
        password.encode(),
        salt=salt,
        n=16384,
        r=8,
        p=1
    )

    # Truncate the new hash to 37 bits
    hash_as_int = int.from_bytes(hashed_password, "big")
    truncated_hash = hash_as_int & ((1 << 37) - 1)

    # Compare with the stored truncated hash
    return truncated_hash == stored_truncated_hash


# Example usage
if __name__ == "__main__":
    password = "secure_password_123"

    # Step 1: Hash the password using scrypt
    truncated_hash, salt = hash_password_scrypt(password)
    print(f"Truncated scrypt hash (37 bits): {truncated_hash}")
    print(f"Salt: {salt.hex()}")

    # Step 2: Verify the password
    is_valid = verify_password_scrypt(password, salt, truncated_hash)
    print(f"Password verification result: {is_valid}")

    # Test with an incorrect password
    is_valid_incorrect = verify_password_scrypt("wrong_password", salt, truncated_hash)
    print(f"Incorrect password verification result: {is_valid_incorrect}")

import hashlib

# This Python script calculates the SHA256 checksum of a specified file
# (in this case, an ISO file) to verify its integrity. It reads the file
# in chunks to avoid memory issues with large files, computes the SHA256
# hash, and compares it to a known reference checksum. If the calculated
# hash matches the reference, the script confirms that the file's integrity
# is intact; otherwise, it flags a checksum mismatch.

# Open the file in binary mode
file_path = r"C:\Users\Christoph\Downloads\archlinux-2024.09.01-x86_64.iso"

# Create a SHA256 hash object
sha256_hash = hashlib.sha256()

# Read the file in chunks to avoid memory issues with large files
with open(file_path, "rb") as f:
    # Read the file in 64KB chunks
    for byte_block in iter(lambda: f.read(65536), b""):
        sha256_hash.update(byte_block)

# Get the final hexadecimal digest
calculated_sha256 = sha256_hash.hexdigest()

# Your known sha256 reference value
sha256_reference = "1652f3cee1b9857742123d392bb467bc5472ecd59a977bd6e17b7c379607b20c"

# Compare the calculated hash with the reference hash
if calculated_sha256 == sha256_reference:
    print("SHA256 Checksum ok")
else:
    print("SHA256 Checksum Failed")

# Print the calculated sha256 value for verification
print(f"Calculated SHA256: {calculated_sha256}")

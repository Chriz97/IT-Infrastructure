import math
# Public Key ist immer (e, n)
# Private  Key ist immer (d, n)

# p und q sind immer zwei primzahlen
p = 23
q = 17

# Formeln für n und phi(n)
n = p * q
phi_n = (p - 1) * (q - 1)

# E muss man selber suchen muss relative prime sein
e = 119

if math.gcd(e, phi_n) == 1:
    print("\033[34m e and phi_n are relatively prime\033[0m")
else:
    print("\033[31m e and phi_n are not relatively prime \033[0m")

# Sympy berechnet mithilfe von e und phi_n das d für den Private Key
d = pow(e, -1, phi_n)

print(f"Public Key (e,n): {e, n}")
print(f"Private Key (d,n): {d, n}")

public_key = (e, n)
private_key = (d, n)

message = "hello this is my message"


def encrypt_function(message, public_key):
    e, n = public_key
    encrypted_numbers = []
    for char in message:
        encrypted_numbers.append((ord(char) ** e) % n)
    return encrypted_numbers


ciphertext = (encrypt_function(message, public_key))

print(ciphertext)


def decrypt_function(ciphertext, private_key):
    d, n = private_key
    decrypted_numbers = []
    for num in ciphertext:
        decrypted_numbers.append((num ** d) % n)
    decrypted_text = ""
    for num in decrypted_numbers:
        decrypted_text += chr(num)
    return decrypted_text


print(decrypt_function(ciphertext, private_key))

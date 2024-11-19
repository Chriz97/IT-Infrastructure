def mod_exp(base, exponent, modulus):
    result = 1
    while exponent > 0:
        if exponent % 2 == 1:
            result = (result * base) % modulus
        base = (base * base) % modulus
        exponent = exponent // 2
    return result

def diffie_hellman():
    # Diffie-Hellman parameters (prime modulus and primitive root modulo)
    n = 23
    g = 5

    # Alice's private key
    x = 7

    # Bob's private key
    y = 3

    # Compute public values
    X = mod_exp(g, x, n)
    Y = mod_exp(g, y, n)

    # Transmit public values
    print("Transmitting X to Bob:", X)
    print("Transmitting Y to Alice:", Y)

    # Compute shared secret key
    K1 = mod_exp(Y, x, n)
    K2 = mod_exp(X, y, n)

    # Check if the shared secret keys match
    if K1 == K2:
        print("Shared secret key (K):", K1)
    else:
        print("Error: Shared secret keys do not match!")

# Perform Diffie-Hellman key exchange
diffie_hellman()

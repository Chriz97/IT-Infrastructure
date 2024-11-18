import os
import subprocess

# Function to generate SSH keys
def generate_ssh_key(key_name="id_rsa", passphrase=""):
    """
    Generate an SSH key pair.
    :param key_name: Name of the SSH private key file.
    :param passphrase: Passphrase for the private key (default is empty for no passphrase).
    """
    ssh_dir = os.path.expanduser("~/.ssh")
    private_key_path = os.path.join(ssh_dir, key_name)
    public_key_path = f"{private_key_path}.pub"

    # Ensure ~/.ssh directory exists
    if not os.path.exists(ssh_dir):
        os.makedirs(ssh_dir)
        os.chmod(ssh_dir, 0o700)
        print(f"Created SSH directory: {ssh_dir}")

    # Check if key already exists
    if os.path.exists(private_key_path):
        print(f"SSH key '{private_key_path}' already exists. Aborting to prevent overwrite.")
        return

    # Generate the SSH key
    try:
        print("Generating SSH key pair...")
        subprocess.run(
            ["ssh-keygen", "-t", "rsa", "-b", "2048", "-f", private_key_path, "-N", passphrase],
            check=True
        )
        print(f"SSH key pair generated successfully:\nPrivate key: {private_key_path}\nPublic key: {public_key_path}")
    except subprocess.CalledProcessError as e:
        print(f"Error generating SSH key pair: {e}")

# Main execution
if __name__ == "__main__":
    key_name = input("Enter the desired SSH key name (default: id_rsa): ") or "id_rsa"
    passphrase = input("Enter a passphrase (leave blank for no passphrase): ")
    generate_ssh_key(key_name, passphrase)

#!/bin/bash
# Bash Variables Script

# Declaring and Using Variables
# Variables in Bash are assigned without spaces around the '=' sign.
name="John"
echo "Hello, $name!"  # Outputs: Hello, John!

# Arithmetic Operations with Variables
# Use $((...)) for arithmetic calculations.
num1=5
num2=3
sum=$((num1 + num2))
echo "The sum of $num1 and $num2 is $sum."  # Outputs: The sum of 5 and 3 is 8.

# Reading Input into a Variable
# The 'read' command is used to accept input from the user.
echo "Enter your age:"
read age
echo "You are $age years old."

# Special Variables
# $0: Name of the script
# $1, $2, ...: Positional parameters (arguments passed to the script)
# $#: Number of arguments
# $*: All arguments as a single string
# $@: All arguments as an array
# $$: Process ID of the script
# $? Exit status of the last executed command
echo "Script name: $0"
echo "First argument: $1"
echo "Number of arguments: $#"

# Environment Variables
# Access predefined environment variables (e.g., $HOME, $PATH)
echo "Your home directory is $HOME."
echo "Your PATH is $PATH."

# Exporting Variables
# Export makes a variable available to child processes.
export my_var="Exported Variable"
bash -c 'echo "Child process can access: $my_var"'  # Outputs: Child process can access: Exported Variable

# Arrays in Bash
# Arrays are indexed collections of values.
fruits=("Apple" "Banana" "Cherry")
echo "First fruit: ${fruits[0]}"  # Outputs: First fruit: Apple
echo "All fruits: ${fruits[@]}"   # Outputs: All fruits: Apple Banana Cherry

# Append to an Array
fruits+=("Date")
echo "Updated fruits: ${fruits[@]}"  # Outputs: Updated fruits: Apple Banana Cherry Date

# Associative Arrays (Bash 4+)
# Associative arrays use named keys instead of numeric indexes.
declare -A capitals
capitals[France]="Paris"
capitals[Germany]="Berlin"
echo "Capital of France: ${capitals[France]}"  # Outputs: Capital of France: Paris

# Default Variable Values
# Use ${var:-default} to provide a default value if the variable is unset or empty.
unset my_var
echo "Unset variable: ${my_var:-DefaultValue}"  # Outputs: Unset variable: DefaultValue

# Modifying Variables
# Use += for string concatenation.
greeting="Hello"
greeting+=" World!"
echo $greeting  # Outputs: Hello World!

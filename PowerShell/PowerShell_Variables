# PowerShell Basics: Variables

# Declaring a simple variable
# Variables in PowerShell start with a $ symbol
$greeting = "Hello, World!"
Write-Host $greeting  # Output: Hello, World!

# Integer variable
# PowerShell automatically assigns the data type based on the value
$age = 25
Write-Host "Age:" $age  # Output: Age: 25

# Float (decimal) variable
# PowerShell supports different numerical types like floats
$price = 19.99
Write-Host "Price:" $price  # Output: Price: 19.99

# Boolean variable
# Boolean variables store True/False values
$isAdmin = $true
Write-Host "Is Admin:" $isAdmin  # Output: Is Admin: True

# Array variable
# Arrays store multiple values in a single variable
$fruits = @("Apple", "Banana", "Cherry")
Write-Host "Fruits:" $fruits  # Output: Fruits: Apple Banana Cherry

# Accessing Array Elements
# Use indexes to access individual elements in an array
Write-Host "First fruit:" $fruits[0]  # Output: First fruit: Apple

# Hash table (Dictionary) variable
# Hash tables store key-value pairs and are defined with @{ key = value; ... }
$person = @{
    Name = "John Doe"
    Age = 30
    Occupation = "Developer"
}
Write-Host "Person's Name:" $person["Name"]  # Output: Person's Name: John Doe

# Changing a variable's value
# Variables can be reassigned with a new value
$greeting = "Hello World!"
Write-Host $greeting  # Output: Hello World!

# Working with Environment Variables
# Environment variables are accessed through the $env: scope
Write-Host "System Path:" $env:Path  # Output: Prints the system's PATH environment variable

# Calculating with variables
# PowerShell allows arithmetic operations with numeric variables
$num1 = 10
$num2 = 20
$sum = $num1 + $num2
Write-Host "Sum:" $sum  # Output: Sum: 30

# Variable Scope Example (Local vs. Global Scope)
# By default, variables are local to the script or function
function Test-VariableScope {
    $localVar = "I'm local"
    $global:globalVar = "I'm global and not local"
    Write-Host $localVar
}
Test-VariableScope
Write-Host $globalVar  # Output: I'm global and not local

# Null values
# Variables can be assigned $null, representing an undefined or empty value
$emptyVar = $null
Write-Host "Empty Variable:" $emptyVar  # Output: Empty Variable: (no output)

# Constants
# To declare a constant that cannot be changed, use the [const] keyword
[const]$pi = 3.14159
Write-Host "Pi:" $pi  # Output: Pi: 3.14159
# Attempting to change $pi will result in an error

# Here-Strings (multi-line strings)
# Here-Strings are enclosed in @" "@ or @' '@ and are useful for multi-line text
$multiLineText = @"
This is a multi-line string.
Each line is preserved.
Useful for scripts or long text.
"@
Write-Host $multiLineText

# String interpolation with variables
# Use double quotes to embed variables directly within a string
$name = "Alice"
Write-Host "Hello, $name!"  # Output: Hello, Alice!


# PowerShell Basics: Comparison Operators

# -eq (Equal to)
# Checks if two values are equal
# Example: Compare if $a equals $b
$a = 5
$b = 5
if ($a -eq $b) {
    Write-Host "$a is equal to $b"  # Output: 5 is equal to 5
}

# -ne (Not equal to)
# Checks if two values are not equal
# Example: Compare if $a is not equal to $b
$a = 5
$b = 10
if ($a -ne $b) {
    Write-Host "$a is not equal to $b"  # Output: 5 is not equal to 10
}

# -gt (Greater than)
# Checks if the value on the left is greater than the value on the right
# Example: Compare if $a is greater than $b
$a = 10
$b = 5
if ($a -gt $b) {
    Write-Host "$a is greater than $b"  # Output: 10 is greater than 5
}

# -lt (Less than)
# Checks if the value on the left is less than the value on the right
# Example: Compare if $a is less than $b
$a = 5
$b = 10
if ($a -lt $b) {
    Write-Host "$a is less than $b"  # Output: 5 is less than 10
}

# -ge (Greater than or equal to)
# Checks if the value on the left is greater than or equal to the value on the right
# Example: Compare if $a is greater than or equal to $b
$a = 5
$b = 5
if ($a -ge $b) {
    Write-Host "$a is greater than or equal to $b"  # Output: 5 is greater than or equal to 5
}

# -le (Less than or equal to)
# Checks if the value on the left is less than or equal to the value on the right
# Example: Compare if $a is less than or equal to $b
$a = 5
$b = 10
if ($a -le $b) {
    Write-Host "$a is less than or equal to $b"  # Output: 5 is less than or equal to 10
}

# -like (Pattern matching with wildcards)
# Checks if a string matches a pattern. Use '*' as a wildcard.
# Example: Check if $name starts with 'A'
$name = "Alice"
if ($name -like "A*") {
    Write-Host "$name starts with A"  # Output: Alice starts with A
}

# -notlike (Pattern matching with wildcards, but not matching)
# Checks if a string does not match a pattern.
# Example: Check if $name does not start with 'B'
if ($name -notlike "B*") {
    Write-Host "$name does not start with B"  # Output: Alice does not start with B
}

# -match (Regular expression matching)
# Checks if a string matches a regular expression pattern
# Example: Check if $email contains a valid email format
$email = "example@domain.com"
if ($email -match "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b") {
    Write-Host "$email is a valid email format"  # Output: example@domain.com is a valid email format
}

# -contains (Checks if a collection contains a specified value)
# Example: Check if $numbers array contains the value 3
$numbers = @(1, 2, 3, 4, 5)
if ($numbers -contains 3) {
    Write-Host "Array contains 3"  # Output: Array contains 3
}

# -notcontains (Checks if a collection does not contain a specified value)
# Example: Check if $numbers array does not contain the value 6
if ($numbers -notcontains 6) {
    Write-Host "Array does not contain 6"  # Output: Array does not contain 6
}

# -in (Checks if a value is in a collection)
# Example: Check if 3 is in $numbers array
if (3 -in $numbers) {
    Write-Host "3 is in the array"  # Output: 3 is in the array
}

# -notin (Checks if a value is not in a collection)
# Example: Check if 6 is not in $numbers array
if (6 -notin $numbers) {
    Write-Host "6 is not in the array"  # Output: 6 is not in the array
}


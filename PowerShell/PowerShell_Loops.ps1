# PowerShell Basics: Loops

# For Loop
# The for loop runs a block of code a specified number of times
# Example: Print numbers 1 to 10
for ($i = 1; $i -le 10; $i++) {
    Write-Host "For Loop Iteration:" $i  # Output: For Loop Iteration: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
}

# Foreach Loop
# The foreach loop iterates over each item in a collection (e.g., an array)
# Example: Print each fruit in the array
$fruits = @("Apple", "Banana", "Cherry")
foreach ($fruit in $fruits) {
    Write-Host "Fruit:" $fruit  # Output: Fruit: Apple, Banana, Cherry
}

# While Loop
# The while loop continues to run as long as the condition is true
# Example: Print numbers 1 to 3
$counter = 1
while ($counter -le 3) {
    Write-Host "While Loop Counter:" $counter
    $counter++
}

# Do-While Loop
# The do-while loop runs the code block at least once, then continues if the condition is true
# Example: Print numbers 1 to 3
$counter = 1
do {
    Write-Host "Do-While Loop Counter:" $counter
    $counter++
} while ($counter -le 3)

# Do-Until Loop
# The do-until loop runs the code block at least once, then stops when the condition becomes true
# Example: Print numbers 1 to 3
$counter = 1
do {
    Write-Host "Do-Until Loop Counter:" $counter
    $counter++
} until ($counter -gt 3)

# Foreach-Object Loop
# The foreach-object loop processes each item in a collection or pipeline
# Example: Print each number in the range 1 to 3 using the pipeline
1..3 | ForEach-Object { 
    Write-Host "Foreach-Object Pipeline Item:" $_  # Output: Foreach-Object Pipeline Item: 1, 2, 3
}

# Break Statement
# The break statement exits a loop prematurely
# Example: Stop the loop when $i equals 3
for ($i = 1; $i -le 5; $i++) {
    if ($i -eq 3) { break }
    Write-Host "For Loop with Break:" $i  # Output: For Loop with Break: 1, 2
}

# Continue Statement
# The continue statement skips the current iteration and moves to the next one
# Example: Skip the number 3
for ($i = 1; $i -le 5; $i++) {
    if ($i -eq 3) { continue }
    Write-Host "For Loop with Continue:" $i  # Output: For Loop with Continue: 1, 2, 4, 5
}

# Nested Loops
# You can place loops inside other loops, known as nested loops
# Example: Print a 3x3 grid of numbers
for ($i = 1; $i -le 3; $i++) {
    for ($j = 1; $j -le 3; $j++) {
        Write-Host "Nested Loop - Row $i, Column $j"
    }
}


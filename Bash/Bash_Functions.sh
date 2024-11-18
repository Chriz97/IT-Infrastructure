#!/bin/bash

# Function 1: Simple Print Function
function func1 {
    echo "This is an example of a function"
}

# Function 2: Square a Number
function square {
    local num=$1
    echo $((num * num))
}

# Function 3: Display a Greeting
function greet {
    local name=$1
    echo "Hello, $name! Welcome to Bash scripting."
}

# While Loop Example
count=1
while [ $count -le 5 ]
do
    func1
    echo "Square of $count is $(square $count)"
    count=$((count + 1))
done

# For Loop Example
echo "Using a for loop to greet a list of names:"
names=("Alice" "Bob" "Charlie")
for name in "${names[@]}"
do
    greet "$name"
done

# Function 4: Calculate Factorial Using Recursion
function factorial {
    local num=$1
    if [ $num -le 1 ]; then
        echo 1
    else
        echo $((num * $(factorial $((num - 1)) )))
    fi
}

# Using the Factorial Function
echo "Calculating factorials:"
for i in {1..5}
do
    echo "Factorial of $i is $(factorial $i)"
done

# Function 5: Generate a Sequence of Numbers
function generate_sequence {
    local start=$1
    local end=$2
    seq $start $end
}

# Using the Sequence Generator
echo "Generated sequence from 1 to 10:"
generate_sequence 1 10

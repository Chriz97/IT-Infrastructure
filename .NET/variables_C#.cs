using System;

namespace ConsoleApp1
{
    class Program
    {
        static void Main(string[] args)
        {
            // This script demonstrates how Variables are defined in C#
            Console.WriteLine("Welcome to this C# Console App!");

            int age = 27;
            Console.WriteLine("Age: " + age);

            // Declare a variable of type double (for decimals)
            double height = 188;
            Console.WriteLine("Height: " + height + " cm");

            // Declare a variable of type string (for text)
            string name = "Christoph";
            Console.WriteLine("Name: " + name);

            // Declare a variable of type char (for a single character)
            char initial = 'A';
            Console.WriteLine("Initial: " + initial);

            // Declare a variable of type bool (true/false)
            bool isStudent = false;
            Console.WriteLine("Is Student: " + isStudent);

            bool isDev = true;
            Console.WriteLine("Is Dev: " + isDev);

            // Demonstrate concatenation of strings and variables
            string fullName = name + " Mayer";
            Console.WriteLine("Full Name: " + fullName);

            // Demonstrate using variables in calculations
            int yearOfBirth = 2024 - age;
            Console.WriteLine("Year of Birth: " + yearOfBirth);

            // Declare multiple variables in one line
            int x = 5, y = 10, z = 15;
            Console.WriteLine("x: " + x + ", y: " + y + ", z: " + z);

            // Use constants
            const double Pi = 3.14159; // Pi is a constant and cannot be changed
            Console.WriteLine("Pi: " + Pi);

            // Demonstrate modifying a variable
            age = 30; // Changing the value of the 'age' variable
            Console.WriteLine("Updated Age: " + age);
            
            Loops loops = new Loops();
            loops.DemonstrateLoops();
        }
    }
}

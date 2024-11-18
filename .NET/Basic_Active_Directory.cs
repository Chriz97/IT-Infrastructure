using System;
using System.DirectoryServices;

class CreateADUserWithPasswordAndGroup {
    static void Main() {
        string ldapPath = "LDAP://DC=testlab,DC=local";  // Update this to your domain's LDAP path
        string userName = "jdoe";
        string fullName = "John Doe";
        string password = "C0mpl3xP@ssw0rd!";  // Use a strong password
        string groupName = "IT Department";

        try {
            // Step 1: Connect to the Directory Entry
            DirectoryEntry entry = new DirectoryEntry(ldapPath);

            // Step 2: Create the new user
            Console.WriteLine($"Creating user {fullName}...");
            DirectoryEntry newUser = entry.Children.Add($"CN={fullName}", "user");
            newUser.Properties["samAccountName"].Value = userName;
            newUser.Properties["userPrincipalName"].Value = $"{userName}@testlab.local";
            newUser.CommitChanges();
            Console.WriteLine("User created successfully.");

            // Step 3: Set the user's password
            Console.WriteLine("Setting password...");
            newUser.Invoke("SetPassword", new object[] { password });
            newUser.Properties["pwdLastSet"].Value = 0;  // Force password change at next login (set to -1 to disable)
            newUser.CommitChanges();
            Console.WriteLine("Password set successfully.");

            // Step 4: Enable the user account
            Console.WriteLine("Enabling user account...");
            int userAccountControl = (int)newUser.Properties["userAccountControl"].Value;
            newUser.Properties["userAccountControl"].Value = userAccountControl & ~0x2;  // Enable account by removing "disabled" flag
            newUser.CommitChanges();
            Console.WriteLine("User account enabled.");

            // Step 5: Add the user to a group
            Console.WriteLine($"Adding user to group {groupName}...");
            DirectoryEntry group = entry.Children.Find($"CN={groupName}", "group");
            group.Invoke("Add", new object[] { newUser.Path });
            group.CommitChanges();
            Console.WriteLine($"User added to group {groupName} successfully.");
        }
        catch (Exception ex) {
            Console.WriteLine($"An error occurred: {ex.Message}");
        }
    }
}

---
name: godos-manage
description: Manage todo lists using the godos CLI application. Create, list, complete, and organize tasks across multiple lists.
license: MIT
compatibility: Requires godos CLI to be installed and available in PATH.
metadata:
  author: assistant
  version: "1.0"
---

Manage todo lists using the godos command-line application.

**Overview**

The godos CLI is a todo list manager that allows you to:
- Create and manage multiple todo lists
- Add, list, complete, and remove todos
- Organize tasks by list name
- Track completion status

**Common Commands**

1. **List todos**
   ```bash
   godos list [--list <name>] [--all]
   ```
   - Default list is "todo"
   - Use `--all` to show all lists
   - Use `--list <name>` to show a specific list

2. **Add a todo**
   ```bash
   godos add "<text>" [--list <name>]
   ```
   - Add a new todo item to the specified list (default: "todo")
   - Text should be quoted if it contains spaces

3. **Mark todo as complete**
   ```bash
   godos done <number> [--list <name>]
   ```
   - Mark a todo as complete by its number
   - Number is shown in the list output

4. **Remove a todo**
   ```bash
   godos rm <number> [--list <name>]
   ```
   - Permanently remove a todo by its number

5. **Manage lists**
   ```bash
   godos lists                    # Show all lists
   godos lists create <name>      # Create a new list
   godos lists rename <old> <new> # Rename a list
   godos lists delete <name>      # Delete a list
   ```

**Global Flags**
- `--dir <path>` - Override storage directory for todo lists

**Usage Guidelines**

When the user wants to:
- **View todos**: Use `godos list` with appropriate flags
- **Add a task**: Use `godos add` with the task description
- **Complete a task**: First list todos to get the number, then use `godos done <number>`
- **Remove a task**: First list todos to get the number, then use `godos rm <number>`
- **Work with multiple lists**: Use the `--list` flag or `godos lists` commands
- **See all tasks**: Use `godos list --all`

**Examples**

```bash
# Add a task to the default "todo" list
godos add "Review pull requests"

# Add a task to a specific list
godos add "Buy groceries" --list personal

# List all todos
godos list --all

# List todos from a specific list
godos list --list work

# Mark todo #3 as complete
godos done 3

# Remove todo #5
godos rm 5

# Create a new list
godos lists create work

# Show all lists
godos lists
```

**Best Practices**

1. Always list todos first to get the correct number before marking done or removing
2. Use descriptive list names to organize tasks by context (work, personal, shopping, etc.)
3. Quote todo text that contains spaces or special characters
4. Use `--all` flag to get an overview of all tasks across all lists
5. Confirm with the user before deleting lists or removing todos

**Error Handling**

- If godos is not installed, inform the user and provide installation instructions
- If a list doesn't exist, suggest creating it first with `godos lists create`
- If a todo number is invalid, list the todos again to show valid numbers
- If operations fail, show the error message and suggest corrections

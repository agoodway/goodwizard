# Project automation recipes

# Start the agent
up:
    mix goodwizard.start

# Start the CLI channel
cli:
    mix goodwizard.cli

# Run setup
setup:
    mix goodwizard.setup

# Show agent status
status:
    mix goodwizard.status

# Deploy to production
deploy:
    # TODO: Configure deployment

# Run tests
test:
    mix test

# Run quality checks (compile, format, credo, doctor, dialyzer, test)
check:
    mix check

# Compile the project
build:
    mix compile

# Clean build artifacts
clean:
    mix clean
    rm -rf _build deps

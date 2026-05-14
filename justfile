# Project automation recipes

# Run tests
test:
    mix test

# Run quality checks
check:
    mix credo --strict

# Compile the project
build:
    mix compile

# Clean build artifacts
clean:
    mix clean
    rm -rf _build deps

# Format code
fmt:
    mix format

# Fetch dependencies
deps:
    mix deps.get

# Copy OpenAPI schema from app
update:
    cp ../app/openapi.json openapi.json

# Publish subtree to goodissues_ex remote
publish:
    cd ../ && git subtree push --prefix=goodissues_ex goodissues_ex main

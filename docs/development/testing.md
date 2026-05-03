# Testing

## Running tests

```bash
# All tests
make test

# Unit tests only
make test-unit

# Integration tests only
make test-integration

# With coverage
make coverage
```

## Test markers

| Marker | Description |
|---|---|
| `unit` | Fast, isolated unit tests |
| `integration` | Tests that use real I/O or external services |
| `slow` | Tests that take longer than 1 second |
| `pdf` | PDF document processing tests |
| `image` | Image document processing tests |

.PHONY: help lint format format-check type-check security test test-unit test-integration coverage coverage-report check-coverage pre-push clean docs

help:  ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

lint:  ## Run ruff linter
	uv run ruff check .

format:  ## Format code with ruff
	uv run ruff format .

format-check:  ## Check code formatting
	uv run ruff format --check .

type-check:  ## Run mypy type checker
	uv run mypy src/docunderstand --show-error-codes

security:  ## Run Bandit security scanner
	uv run bandit -c pyproject.toml -r src/

test:  ## Run all tests in parallel
	uv run pytest tests/ -n auto

test-unit:  ## Run unit tests in parallel
	uv run pytest tests/ -n auto -m unit

test-integration:  ## Run integration tests in parallel
	uv run pytest tests/ -n auto -m integration

coverage:  ## Run tests with coverage measurement
	uv run pytest tests/ -n auto \
		--cov=src \
		--cov-branch \
		--cov-report=term-missing \
		--cov-report=xml

coverage-report:  ## Generate HTML coverage report and open in browser
	uv run coverage html
	@open htmlcov/index.html || xdg-open htmlcov/index.html || \
		echo "Coverage report generated at htmlcov/index.html"

check-coverage:  ## Validate coverage meets 80% threshold
	@uv run coverage report --fail-under=80 || \
		(echo "❌ Coverage below 80% threshold" && exit 1)
	@echo "✅ Coverage meets threshold"

docs:  ## Build documentation
	uv run mkdocs build --strict

docs-serve:  ## Serve documentation locally
	uv run mkdocs serve

pre-push: format-check lint type-check security coverage check-coverage  ## Run all pre-push checks (mirrors CI)
	@echo "✅ All pre-push checks passed!"

clean:  ## Clean up cache files
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .mypy_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	rm -f test-results*.xml coverage.xml 2>/dev/null || true
	rm -rf htmlcov/ site/ 2>/dev/null || true

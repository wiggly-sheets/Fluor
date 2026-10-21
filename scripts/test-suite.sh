#!/usr/bin/env bash
#
# Fluor — run the test suite and check the result.
#
# The script runs the suite, keeps the output in a log file and fails when
# the suite does not report the expected number of passing tests. The CI
# workflow and the release workflow call it, so both gates use one rule.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT
cd "$ROOT"

readonly EXPECTED='Executed 21 tests, with 0 failures'
readonly LOG="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/fluor-test-output.log"

# The exit code of the suite must survive: a failing suite stops the run.
set +e
make test 2>&1 | tee "$LOG"
suite_status="${PIPESTATUS[0]}"
set -e

if [ "$suite_status" -ne 0 ]; then
	echo "::error::the test suite failed with exit code ${suite_status}"
	exit "$suite_status"
fi

if ! grep -q "$EXPECTED" "$LOG"; then
	echo '::error::the test suite did not report 21 passing tests'
	exit 1
fi

echo 'The test suite passed 21 tests.'

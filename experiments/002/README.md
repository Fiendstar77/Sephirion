# Experiment 002: acoustic resonance across recursive realms

All dynamics, analysis, and validation use Common Lisp with SBCL and its bundled
ASDF/UIOP. No external Lisp, numerical, plotting, or Python dependencies are needed.

From the repository root:

```sh
sbcl --script scripts/test.lisp
sbcl --script experiments/002/run.lisp
sbcl --script experiments/002/check-recordings.lisp
```

The experiment writes CSV files to this directory and prints its observations,
validation status, and interpretation. Existing measurements are replaced when
rerunning. To preserve the recorded data, choose another output directory:

```sh
sbcl --script experiments/002/run.lisp /tmp/sephirion-002-replay/
```

`fixtures.lisp` specifies all initial conditions, coupling graphs, drive choices,
and the independent three-node modal reference. `experiment.lisp` defines the
sweeps, pair controls, free-transfer comparisons, peak extraction, and acceptance
tests. The pair reference uses the preserved original analytical solver.

## Recorded measurements

| File | Contents |
| --- | --- |
| `responses.csv` | 558 per-realm response records: 8 scenarios, each with 31 frequencies; pair scenarios have 2 nodes, chains have 3 |
| `peaks.csv` | 48 largest-sample/interior-peak records, with angular frequency, amplitude and principal phase |
| `nested-chain-trace.csv` | 6777 per-realm rows at omega=1, including startup and settling |
| `transfer-0.0.csv`, `transfer-0.1.csv`, `transfer-0.5.csv` | 402 per-realm rows each, including initial/final states, for unforced undamped pairs |
| `transfer-summary.csv` | Initial total energy, maximum receiver local-energy fraction, first 10% crossing and maximum energy drift |
| `results.txt` | Experiment observations and the 564-comparison validation summary |
| `test-output.txt` | Full automated test observations, tolerances and rejection checks |
| `pair-baseline-regression.txt` | Original 61-frequency pair sweep rerun; original CSVs unchanged |
| `csv-validation.txt` | Integrity checks on recorded CSV values and energy identities |
| `reproducibility.txt` | Separate-process replay, old-experiment regression, and unchanged-baseline checks |
| `SHA256SUMS` | Hashes of the final measurements and validation records, checked from repository root |
| `development-csv-reader-failure.txt` | Preserved initial CSV-checker syntax failure, corrected before final validation |

All numeric output uses normalized acoustic units and angular frequency, not Hz.
Displacement and velocity are recorded in the traces and at each sweep's endpoint.
The response CSV also records measured/analytical amplitude and phase, absolute
complex error, mean allocated realm energy over the eight measured cycles, final
local/allocated/total energy, cumulative input work and dissipation, actual dt,
final time, and maximum absolute/scaled balance residual over the entire run.

Trace rows are written every 10 integration steps, plus initial and final states.
The transfer summaries and maximum residuals are evaluated every integration step,
not only at trace rows. Energy contributions include half of each incident elastic
coupling's energy; local energy excludes that allocation. Cumulative network-wide
quantities repeat on each realm's trace row and must not be summed across realms.

All driven sweeps start from rest. Frequencies, coefficients, settling windows,
measurement definitions, numerical constraints, and **prespecified tolerances**
are in [the specification](../../docs/SEPHIRION_002_SPECIFICATION.md).
See [the results](../../docs/SEPHIRION_002_RESULTS.md) for observations separated
from interpretation, failed/unexecuted validations, and limitations.

The CSV integrity checker handles this experiment's fixed labels, which contain
no commas. The writer quotes and escapes general identifiers, but the checker is
not intended as a general-purpose CSV library. No plots are needed for validation;
all amplitude, phase, energy, and numerical error records are portable CSV.

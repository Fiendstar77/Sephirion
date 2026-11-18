# SEPHIRION-002: local results

Date: 2026-11-18. Runtime: SBCL 2.6.9. Reference source before this milestone:
`7c4bb19ed9fe9f04c205bc963de6afc65cca20ea`. The source version for these new
records is the commit containing this document. All results are local; no hosted
CI or physical apparatus was used.

## Execution and evidence

The complete repository inventory, existing engines, specifications, results,
tests and measurement formats were inspected before editing. The original
`src/realms.lisp`, `src/acoustics.lisp`, `src/package.lisp`, SEPHIRION-001 documents,
Experiment 001 records, and original acoustic CSV/plot records are unchanged.
The new model resides in the separate `sephirion-acoustic` package.

The [specification](SEPHIRION_002_SPECIFICATION.md) recorded the energy derivation,
measurement protocol, and numerical acceptance tolerances before evaluating the
implementation. No acceptance threshold was relaxed after observing results.

Commands executed from repository root:

```sh
sbcl --script scripts/test.lisp > experiments/002/test-output.txt 2>&1
sbcl --script experiments/002/run.lisp > experiments/002/results.txt 2>&1
sbcl --script experiments/002/check-recordings.lisp > experiments/002/csv-validation.txt 2>&1
sbcl --script experiments/001/run.lisp > /tmp/sephirion-002-realm-regression.txt 2>&1
cmp experiments/001/results.txt /tmp/sephirion-002-realm-regression.txt
sbcl --script experiments/002/run.lisp /tmp/sephirion-002-replay/ > /tmp/sephirion-002-replay-output.txt 2>&1
cmp experiments/002/results.txt /tmp/sephirion-002-replay-output.txt
for p in experiments/002/*.csv; do cmp "$p" "/tmp/sephirion-002-replay/${p##*/}" || exit 1; done
sbcl --script scripts/experiment-0001.lisp > experiments/002/pair-baseline-regression.txt 2>&1
```

The final commands exited 0. Experiment 001's stdout matches its recorded output
byte for byte. A fresh Experiment 002 process reproduced both the full stdout
and all seven CSV files byte for byte. These checks concern this runtime and
machine; they do not assert cross-platform bitwise identity.

The original 61-frequency pair sweep was also rerun and its original recorded
CSVs remained byte-identical. Its output in `pair-baseline-regression.txt` is:

```text
61 frequencies; maximum absolute complex response error: 1.338230d-7
```

`reproducibility.txt` records the successful stdout/CSV comparisons and the
unchanged original source/documents/data check. A measurement manifest can be
checked with `sha256sum -c experiments/002/SHA256SUMS` from repository root.

The combined test command printed its legacy summaries and 50 new test records:

```text
2022 acoustic checks passed.
Realm validation: passed=101 failed=0 unexecuted=0
Acoustic-network validation: passed=50 failed=0 unexecuted=0
```

The complete lines, including observed values and acceptance criteria, are in
[test-output.txt](../experiments/002/test-output.txt). The experiment's summary:

```text
VALIDATION: passed=564 failed=0 unexecuted=0
```

The 564 comparisons comprise 248 analytical-response checks, 248 energy-balance
checks, 31 isolated-receiver checks, 31 matched flat/nested comparisons, and six
free-transfer energy/excitation checks. Raw observations and interpretation are
separately labeled in [results.txt](../experiments/002/results.txt).

The recorded data integrity command printed exactly:

```text
CSV integrity: 558 response rows, 48 peak rows, 3 transfer summaries, 7983 trace rows passed.
```

## Observations: Q1, recovery of the pair and independent chain solution

Over 1000 steps at dt=0.02, maximum q/v difference from the original pair integrator
was 4.44e-16 for the symmetric reference and 7.77e-16 with asymmetric coefficients.
The pair frequency-domain reference is the original independent analytical solver.
The chain reference is a separate normal-mode expansion, not an invocation of the
new integrator or a fit to its output.

Across all 248 scenario/frequency runs and 558 per-realm responses:

| Quantity | Observed maximum | Prespecified limit |
| --- | --- | --- |
| Absolute complex amplitude error | 4.84755e-7 | <5e-6 |
| Scaled energy-balance residual | 2.49719e-8 | <1e-6 |
| Absolute energy-balance residual | 9.05495e-6 | recorded; acceptance uses the scaled residual |

The largest absolute residual is not zero and should not be described as exact
energy conservation. Its corresponding work/loss scale matters. Residual is
`E(t)-E(0)-W(t)+D(t)`, and the specified scaled metric divides its absolute value
by `1+E(0)+abs(W)+D` at every tick, including settling.

The undriven undamped pair and chain energy drift over 100 time units was
2.51827e-8 and 2.77748e-8 relative to initial energy, respectively (<1e-7).
The passive chain showed no positive per-step energy change; its energy at t=20
was 0.0181323 of its initial value (<0.03). For the exact free-mode timestep test,
halving dt from 0.08 to 0.04 reduced state error by a factor of 16.3114 (>12).
The driven balance residual improved by a factor of 12.6282 (>8). The independent
energy directional-derivative check had error 9.50e-13 (<1e-8). Extending the
least-damped settling interval from 400 to 600 changed response by 3.87e-9 (<5e-6).

## Observations: Q2, coupling and energy transfer

Free-transfer runs have identical initial displacements/velocities: q_a=1,
all others zero. There is no drive or damping. They differ only in coupling.

| Kc | Initial total E | Max receiver local E / initial total E, within t=0..40 | First 10% crossing |
| --- | --- | --- | --- |
| 0 | 0.5 | 0 | not reached |
| 0.1 | 0.55 | 0.99791990 | 6.44 |
| 0.5 | 0.75 | 0.96992268 | 2.10 |

The uncoupled receiver remains exactly at rest. Nonzero coupling transfers
excitation and energy to it. The stronger tested coupling reaches the selected
fraction sooner, but the maximum transferred fraction is **not monotonic** across
these finite-window measurements. Initial total energy differs because the same
displacement stores different spring energy as Kc changes. These normalized
fractions and crossing times are not a constant-energy transfer-rate experiment.

Mean allocated energy in the driven nested chain at omega=1:

| Realm | Displacement amplitude | Phase (rad) | Mean allocated energy |
| --- | --- | --- | --- |
| a, root container and driven oscillator | 2.24681675 | -1.12378388 | 2.62196959 |
| b, child of a | 1.65204651 | -1.70334787 | 1.48603375 |
| c, child of a | 1.53388668 | -2.08385425 | 1.19993226 |

Only a is externally driven; c receives excitation through the specified a--b--c
graph. This is a lumped ODE interaction, not evidence of a spatial time of flight.

## Observations: Q3, damping, mismatch and excitation frequency

The receiver b's largest **sampled** driven response in each pair sweep:

| Scenario | omega | Receiver amplitude |
| --- | --- | --- |
| reference: R=0.2, K2=1, Kc=0.5 | 1.00 | 2.45145170 |
| coupling disabled | all samples zero | 0 |
| weak coupling Kc=0.1 | 1.05 | 1.84829424 |
| mismatched K2=2.25 | 1.15 | 1.34243873 |
| low damping R=0.1 | 1.00 | 4.97518597 |
| high damping R=0.5 | 1.05 | 0.89897611 |

With M=1, changing K2 from 1 to 2.25 changes its isolated undamped natural angular
frequency from 1 to 1.5. Coupled forced-response peaks are not automatically at
either isolated natural frequency. The mismatch reduces the largest receiver
response in this sampled band and shifts it. Raising damping reduces its sampled
maximum for the tested settings. The full frequency dependence, phase and multiple
interior peaks are in `responses.csv` and `peaks.csv`; no single-frequency result
is generalized to every graph or parameter set.

The nested and flat chain's far receiver c both have largest sampled amplitude
1.85520866 at omega=1.20. Operational resonance means an interior amplitude sample
larger than its neighbors under the fixed unit drive. Grid spacing is 0.05, so
these are neither fitted peak frequencies nor proof that all possible peaks were
resolved. The phase of the zero-amplitude isolated receiver is not interpreted.

## Observations and interpretation: Q4, recursive organization

The physical graph, canonical node order, coefficients, initial conditions,
excitation, and timestep are identical between the flat and nested chains.
Only parent metadata differs. The root container a is the same physical oscillator
as flat node a; there is no extra degree of freedom in the nested case.

The automated test compares the entire q/v/work/loss trajectory over 5000 ticks
(100 reference time units): maximum difference is exactly 0. Each of the 31
frequency-response/accounting comparisons also gives exactly 0 difference.
A nested no-coupling control leaves both undriven children exactly at rest.

**Null result:** recursive containment introduces no additional physical behavior
in this model when the explicit coupling graph and physical parameters are held
fixed. This is the expected outcome, not a failed validation. Acoustic effects
are explained by the declared graph and equations. Nothing here establishes or
rules out benefits of other, separately specified recursive architectures.

## Failed, passed, and unexecuted validation

Final required tests: **50 passed, 0 failed, 0 unexecuted**. Experiment 002:
**564 passed, 0 failed, 0 unexecuted**. Legacy regressions: 2022 acoustic assertions
and 101 exact-rational realm assertions passed; original Experiment 001 output
was unchanged. CSV integrity, separate-process replay, and unchanged-baseline
checks passed. The 2022 legacy count includes 2000 individual passive-energy steps.

**Resolved development failure:** the first invocation of the new CSV integrity
script failed to read because a closing parenthesis was missing in its local
function definitions. The raw failure is retained in
[development-csv-reader-failure.txt](../experiments/002/development-csv-reader-failure.txt).
The script was corrected and rerun successfully. This was a validation-script
syntax error, not an observed integration or energy-accounting failure. No
integration-accuracy or energy-balance acceptance test failed in the recorded runs.
The intentionally induced arithmetic overflow was rejected as required, and its
predecessor snapshot remained unchanged.

Unexecuted: cross-platform replay, other Lisp implementations, hardware acoustic
calibration, spatial propagation, arbitrary coefficient ranges, scale/performance
benchmarks, exhaustive verification, and hosted CI. Plots were not generated for
this milestone; portable CSV is the measurement artifact. Emergent intelligence,
cognition, consciousness, metaphysical resonance, autonomous self-modification,
and unconnected interactions remain outside the experiment.

## Limits

These are linear lumped acoustic approximations with normalized coefficients.
Recursion is a containment/routing organization over explicit physical degrees
of freedom. RK4 is neither symplectic nor adaptive; finite-horizon conservation
and convergence observations do not guarantee long-term conservation or stability
for arbitrary parameters. Fixed settling windows, grid frequencies and finite
observation windows limit the conclusions. A scalar energy contribution includes
an explicitly conventional half-spring allocation; raw local energy is also saved.
No unresolved failing milestone validation remains. No unexpected recursive
physical mechanism, fractalization, cognition, or scaling benefit is established.

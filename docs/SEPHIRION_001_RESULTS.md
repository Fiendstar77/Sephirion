# SEPHIRION-001: local validation results

Run date: 2026-11-17. Runtime: SBCL 2.6.9. ASDF loads the local system.
The engine, tests, and experiments have no external Common Lisp dependencies.
These are local execution results; no hosted CI execution is claimed.

## Scope and provenance

The live repository was inspected before editing. GitHub's `main` then pointed
to `8df833f197a9c388e198ed58957942da33d6fcdd`, the initial package skeleton.
The preceding acoustic baseline existed locally as uncommitted source, tests,
documentation, and recorded data. This milestone preserves it and introduces
the independent rational-state realm network specified in
[SEPHIRION_001_SPECIFICATION.md](SEPHIRION_001_SPECIFICATION.md).

The exact declarations and prespecified expected values are in
[experiments/001/experiment.lisp](../experiments/001/experiment.lisp).
The source version is the commit containing this report. No external datasets
or stochastic initialization were used.

## Commands and recorded output

Run from the repository root:

```sh
sbcl --script scripts/test.lisp > experiments/001/test-output.txt 2>&1
sbcl --script experiments/001/run.lisp > experiments/001/results.txt 2>&1
sbcl --script experiments/001/run.lisp > /tmp/sephirion-001-replay.txt 2>&1
cmp experiments/001/results.txt /tmp/sephirion-001-replay.txt
sbcl --script scripts/experiment-0001.lisp > experiments/001/acoustic-regression-output.txt 2>&1
```

All five commands completed with exit code 0. The independent-process comparison
was silent, meaning the full experiment outputs were byte-identical. The first
command produced exactly:

```text
2022 acoustic checks passed.
Realm validation: passed=101 failed=0 unexecuted=0
```

The realm experiment's full output is recorded in
[results.txt](../experiments/001/results.txt), including every rejection message.
Its final validation line is:

```text
VALIDATION: passed=24 failed=0 unexecuted=0
```

The separate acoustic regression produced exactly:

```text
61 frequencies; maximum absolute complex response error: 1.338230d-7
```

That error belongs to the normalized acoustic baseline, not to the exact-rational
realm experiment. Its CSV observations remain in `reports/experiment-0001/`.

## Observations

| Required case | Final status | Recorded observation |
| --- | --- | --- |
| A: signal propagation | PASS | From a=3, b=0, the affine operator 2x+1 yields b[1]=7 while a[1]=3 |
| B: network interaction | PASS | (a,b,c) follows (1,0,0), (1,2,0), (1,4,6), (4,6,18), (13,14,36) |
| C: recursive structure | PASS, 2 comparisons | Explicit input->shell->inner routing gives inner=0,0,1,3 over ticks 0–3; shell's only immediate child is inner |
| D: determinism | PASS | Two fresh executions have identical complete state histories; two separate process outputs also match |
| E: negative control | PASS | Disabling only bc yields (1,0,0), (1,2,0), (1,4,0), (1,6,0), (1,8,0) |
| F: invalid conditions | PASS, 18 comparisons | Every listed invalid case raises model-error explicitly |

The 18 rejection cases cover an empty ID, float state, complex and nonnumeric
signals, oversized state, unsupported operator and coefficient combinations,
invalid enabled flag, duplicate realm and path IDs, missing endpoint and parent,
containment cycle, boundary bypass, invalid step count and execution order,
transformed-signal overflow, and next-state overflow.

At tick 4, the difference between baseline B and control E is exactly
`(12,6,36)`. The controlled intervention removes c's excitation first, then its
feedback into a, then the resulting additional excitation of b. The earlier
ticks in the raw record expose that causal delay.

The 101 realm assertions additionally cover all 36 realm/path evaluation-order
combinations over four ticks, five repeated replay comparisons, rational and
negative arithmetic, exact cancellation through large intermediate sums,
construction-order invariance, snapshot/history ownership, immutable predecessors,
tick/history counts, explicit upward and downward boundary exchange, no implicit
child aggregation, deeper containment, transactional rejection, self paths,
disabled paths, circular/improper declaration lists, unknown realm reads,
denominator bounds, zero-step behavior, and separate experiment-runner symbols.

The retained 2022 acoustic assertions include 2000 individual passive-energy
steps; that count must not be read as 2022 independent acoustic phenomena.

## Interpretation

For the tested fixtures, the engine follows the specified additive recurrence
exactly. An enabled path has the predicted effect; disabling it produces the
prespecified differences. All updates read the previous committed state, and
evaluation-order permutations reproduce the same histories.

Containment is executable as an explicit routing constraint. It neither creates
signals by itself nor lets a child bypass its container. This establishes the
specified recursive organization, not a computational advantage over a flat
implementation of equivalent routes.

The realm experiment has exact rational arithmetic; its successful comparisons
use exact equality, without fitted tolerances. The acoustic baseline instead
uses floating-point integration and an independently computed analytical response.
The two evidence types are separate.

## Failed and unexecuted validation

**Final failures: none.** Final realm tests: 101 passed, 0 failed, 0 unexecuted.
Final Experiment 001: 24 passed, 0 failed, 0 unexecuted. The acoustic tests and
sweep also completed successfully.

During development, the initial realm test run had one failed expected table:
the nested fixture's columns were written as input,inner,shell, whereas the
specified string ordering is inner,input,shell. Inspection confirmed the state
values matched the recurrence; the expected table and its label were corrected.
An imported `run-experiment` symbol also collided with the existing acoustic
runner. The realm experiment now shadows that name in its own package, and an
explicit regression assertion checks that the two runner symbols differ. Final
fresh-process tests and both experiment commands were executed after these fixes.

**Unexecuted / outside this milestone:**

| Research or validation question | Status and reason |
| --- | --- |
| Resonance inside a recursive realm network | UNEXECUTED: no coupling between the rational realm engine and acoustic model is implemented |
| Resonance between unconnected realms | OUT OF SCOPE: no such mechanism is implemented or supported by this experiment |
| Fractalization and scale invariance | UNEXECUTED: containment is implemented, but self-similar generative rules and scale effects are not |
| Physical acoustic calibration or propagation | UNEXECUTED: the preserved acoustic baseline is a normalized lumped model |
| Performance, scalability, or exhaustive verification | UNEXECUTED: small deterministic fixtures only; no benchmark or universal correctness proof |
| Other Common Lisp implementations | UNEXECUTED: only SBCL 2.6.9 was used |
| Hosted CI | UNEXECUTED: local results only |
| Intelligence, consciousness, subjective experience, metaphysics, autonomous self-modification, financial prediction | OUT OF SCOPE |

## Limitations and unresolved issues

No known failing validation case remains for the specified milestone. The additive
state rule, exact rational type, 256-bit bounds, and boundary rules are deliberate
assumptions and remain open to future replacement by explicit, separately tested
models. Feedback can grow until bounds reject a step; no stability guarantee is
claimed. Histories retain all states in memory, lookup is linear, and intermediate
arithmetic has no resource bound. No scalability claim follows.

Snapshots omit topology and operator declarations, so they require the experiment
source for replay. Runtime topology editing, persistence/loading, acoustic
integration, and emergent computation remain unimplemented. The older acoustic
experiment and this realm experiment retain different directory names and source
entry points; their similar numeric labels do not denote one integrated experiment.

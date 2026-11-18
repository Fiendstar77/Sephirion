# Project SEPHIRION

*Recursive Realms · Transformative Paths · Emergent Dynamics*

## Origin and Inspiration

SEPHIRION draws its initial structural inspiration from the sacred Kabbalistic Tree of Life, particularly its representation of interconnected spheres and paths.

This inspiration is acknowledged openly and respectfully.

However, SEPHIRION does not attempt to reproduce, validate, or computationally implement the metaphysical, theological, or spiritual teachings of Kabbalah.

The Tree of Life serves as an architectural starting point, not an explanation of human existence or the nature of reality.

## Scientific Direction

SEPHIRION explores a recursive computational architecture in which:

- **Realms** represent data-bearing structures that may themselves contain entire networks of realms.
- **Paths** transmit and transform signals between realms.
- **Resonance** follows acoustic laws, with explicit oscillatory dynamics, damping, driving, coupling, and energy transfer. Any interaction outside the path network requires a specified acoustic coupling mechanism.
- **Fractalization** is a future research hypothesis concerning organization across recursively nested scales. Finite nesting alone does not establish fractal structure.
- **Emergent dynamics** are investigated through observable interactions and experimental validation.

The architecture is intended to be domain-independent. Financial systems provide one possible experimental environment, not its defining purpose.

All proposed mechanisms remain subject to formal specification, implementation, measurement and falsification.

## Development

Implementation language: **Common Lisp**. The initial development environment uses SBCL and ASDF, with no external Lisp dependencies.

**SEPHIRION-001 implements a minimal recursive realm network:** exact rational
scalar states, validated directed identity/scale/affine paths, explicit containment
boundaries, a global discrete clock, synchronous compute-then-commit updates, and
copied state snapshots and histories. This is a chosen computational model, not
an acoustic simulation or evidence of intelligence.

See the [formal specification](docs/SEPHIRION_001_SPECIFICATION.md),
[validation results](docs/SEPHIRION_001_RESULTS.md), and
[Experiment 001 source and recorded output](experiments/001/README.md).

**SEPHIRION-002 adds acoustic realms in a separate state model:** floating-point
displacement/velocity, passive symmetric elastic couplings, explicit harmonic
pressure drives, and global RK4 integration with input-work and dissipation
accounting. Acoustic containment follows the existing boundary rules. The
exact-rational accumulator is preserved and is not reinterpreted as acoustics.

See the [acoustic-network specification](docs/SEPHIRION_002_SPECIFICATION.md),
[results and limitations](docs/SEPHIRION_002_RESULTS.md), and
[Experiment 002 measurements](experiments/002/README.md). The generalized model
recovers the original pair and tests three-node flat/nested chains. With identical
physical graphs and parameters, changing only containment labels produces the
expected null result: no additional physical behavior.

The original pair remains unchanged with its own [specification](docs/ACOUSTICS.md)
and [report](reports/experiment-0001/README.md). Spatial propagation, physical
calibration, fractalization, and any computational benefit of recursive organization
remain unimplemented or unestablished.

From the repository root, load the system with:

```sh
sbcl --non-interactive \
  --eval '(require :asdf)' \
  --eval '(asdf:load-asd (truename "sephirion.asd"))' \
  --eval '(asdf:load-system "sephirion")'
```

For interactive development, evaluate these forms in a Common Lisp REPL:

```lisp
(require :asdf)
(asdf:load-asd (truename "sephirion.asd"))
(asdf:load-system "sephirion")
(in-package #:sephirion)
```

Run the combined acoustic/realm tests and the realm network experiment:

```sh
sbcl --script scripts/test.lisp
sbcl --script experiments/001/run.lisp
```

The realm experiment prints exact observations, expected values, and validation
counts for propagation, recurrent exchange, nesting, replay, a disabled-path
control, and invalid inputs. Failures exit nonzero. Recorded local run:

```text
2022 acoustic checks passed.
Realm validation: passed=101 failed=0 unexecuted=0
VALIDATION: passed=24 failed=0 unexecuted=0
```

The last line is the separate Experiment 001 summary. These counts are local
validation results, not hosted CI results. See the results document for exact
commands, full outputs, limits, and unexecuted research questions.

Run the acoustic-network experiment and validate its recorded data:

```sh
sbcl --script experiments/002/run.lisp
sbcl --script experiments/002/check-recordings.lisp
```

The shared `scripts/test.lisp` command now also reports:

```text
Acoustic-network validation: passed=50 failed=0 unexecuted=0
```

Experiment 002 reports `passed=564 failed=0 unexecuted=0`. Its 248 driven runs
produce 558 per-realm response records, plus free-transfer and nested-chain traces.
Maximum absolute complex-response error was 4.85e-7 against independent analytical
references (<5e-6 required). The energy-balance and refinement checks passed their
prespecified tolerances. The full experiment stdout and all seven CSV outputs
were reproduced byte for byte in a separate local process. No hosted CI is claimed.

Rerunning replaces Experiment 002's measurements; use an alternate directory to
preserve the recorded files:

```sh
sbcl --script experiments/002/run.lisp /tmp/sephirion-002-replay/
```

Example realm network in a loaded REPL:

```lisp
(let* ((initial
         (sephirion:make-network
          (list (sephirion:make-realm "a" :state 3)
                (sephirion:make-realm "b"))
          (list (sephirion:make-path "ab" "a" "b"
                                     :operator :affine :gain 2 :offset 1))))
       (next (sephirion:step-network initial)))
  (sephirion:print-network-history next))
;; tick 0: "a"=3 "b"=0
;; tick 1: "a"=3 "b"=7
```

To reproduce the separate acoustic frequency sweep and every-tick trace:

```sh
sbcl --script scripts/experiment-0001.lisp
```

Its output files reside in `reports/experiment-0001/`. Optional rendering of the
existing acoustic plot uses `scripts/plot-experiment-0001.py` and matplotlib;
the Common Lisp engine, experiments, and tests require neither Python nor matplotlib.

No emergent intelligence, consciousness, subjective experience, metaphysical
mechanisms, autonomous self-modification, financial prediction, or performance
and scalability claims are established by these demonstrations.

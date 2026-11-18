# Experiment 001: the first executable realm network

This is the SEPHIRION-001 **realm network** experiment. The older acoustic baseline
uses `scripts/experiment-0001.lisp` and `reports/experiment-0001/`; the shared number
does not imply the two models are integrated.

From the repository root, with SBCL installed:

```sh
sbcl --script scripts/test.lisp
sbcl --script experiments/001/run.lisp
```

Only SBCL, its bundled ASDF, and standard Common Lisp are required. Each run creates
fresh topology and states. There are no seeds, external datasets, clocks read from
the operating system, or network services in the experiment.

`experiment.lisp` contains the declarations, expected state histories, negative
conditions, and comparisons. `run.lisp` loads the ASDF system and prints the run.

Recorded final observations:

- [results.txt](results.txt): all A–F comparisons, explicit rejection messages,
  and a separately labeled interpretation.
- [test-output.txt](test-output.txt): combined acoustic and realm test output.
- [acoustic-regression-output.txt](acoustic-regression-output.txt): rerun of the
  previously implemented acoustic sweep after adding the realm engine.

See the [specification](../../docs/SEPHIRION_001_SPECIFICATION.md) and
[results analysis](../../docs/SEPHIRION_001_RESULTS.md) for equations, causal
predictions, exact reproduction commands, validation status, and limitations.

Standard output is not saved automatically; record it with shell redirection.
No expected result is generated from the engine's own transition function.

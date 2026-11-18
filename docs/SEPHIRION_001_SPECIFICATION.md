# SEPHIRION-001: the first executable realm network

Status: implemented reference model, version 0.1.0. Date: 2026-11-17.

## Purpose and evidence boundary

This milestone establishes explicit, measurable state transitions, directed signal
operators, containment, and reproducible execution. The rules below are **chosen
modeling assumptions**, not discovered universal properties of recursive systems.
The experiments test whether this implementation follows those rules. They do
not test whether recursion improves computation or creates intelligence.

The Kabbalistic Tree of Life remains an acknowledged architectural inspiration.
No theological, spiritual, metaphysical, or existential claims are implemented.
The system is domain-independent; it does not perform financial prediction.

## 1. Realm and state

A realm is a declaration `(id, initial-state, parent-id)`. Its identifier is a
nonempty, case-sensitive Common Lisp string, unique across all realms in a network.
The parent is either NIL (a root) or the identifier of one existing realm.
Identifiers are opaque; their spelling has no physical or numerical meaning.

State is one **dimensionless exact rational scalar**. Integers and ratios are
accepted. Floating-point values, complex numbers, nonnumeric values, and automatic
coercions are rejected. State defaults to zero; there is no random initialization.
Negative state is valid. This state is not pressure, energy, acoustic amplitude,
or a probability. The existing acoustic analogue has a separate state model.

For every stored state, operator coefficient, operator input and transformed
signal, both `integer-length(abs(numerator(x))) <= 256` and
`integer-length(denominator(x)) <= 256` must hold. Thus `2^256 - 1` is valid and
`2^256` is invalid. This is a declared representation boundary, not a physical
law, performance guarantee, or stability criterion.

## 2. Directed paths and pure operators

A path has a unique nonempty string ID (a separate namespace from realm IDs),
source realm ID, target realm ID, operator, coefficients, and a Boolean enabled
flag. All endpoints and boundaries are checked at network assembly, including
disabled paths. Parallel paths with distinct IDs and explicit self paths are
allowed. Multiple source/target pairs are not silently merged.

Supported transformations are a closed mathematical vocabulary:

| Operator | T(x) | Parameters |
| --- | --- | --- |
| `:identity` | x | gain=1, offset=0 only |
| `:scale` | gain*x | rational gain; offset=0 only |
| `:affine` | gain*x + offset | rational gain and offset |

No arbitrary function objects, callbacks, evaluation of supplied code, or hidden
operator state are supported. `transform-signal` is pure: it returns only T(x),
including for a disabled path. The enabled flag controls **routing** in a network
step; a disabled path is not evaluated and contributes exactly zero. In particular,
disabling an affine path suppresses its offset as well as its scaled signal.

An affine offset is an explicit constant source. Signals are not conserved
quantities and the additive recurrence is not an acoustic energy model.

## 3. Nesting and boundary semantics

A network owns a nonempty forest of realms. A realm contains its immediate
children by their parent references, recursively. Parent IDs must exist;
self-containment and containment cycles are invalid. State and clock storage
are owned by the network. Containment is an organizational and routing rule,
not a separate hidden simulator or automatic computation of a container's state.

A path is legal only when its endpoints are:

1. siblings with the same parent, including two roots; or
2. an immediate parent and child, in either direction.

Other edges bypass a boundary and are rejected. A child of container A cannot
directly signal a root sibling of A or a child of container B. A lawful route must
pass through the relevant containers as explicit endpoints, one edge per tick.
Every container has its own scalar state. It does not implicitly sum its children's
states, inherit its parent's signals, broadcast to descendants, or observe them
without a path. Siblings and parent/child pairs are still unconnected unless a path
is declared. Nesting alone causes no state change.

The global forest can represent multiple nesting levels without a new state
transition rule. Tests cover a two-level containment chain, and Experiment C
records a root container and its child. No depth or scale benchmark is claimed.

## 4. Clock, aggregation, and two-phase transition

The global tick n is an exact nonnegative integer, initialized to 0. It is a
discrete computational clock with no conversion to physical seconds. All roots,
containers, and descendants share it; there are no substeps or per-realm clocks.

Let x_i[n] be realm i's previously committed state. For each enabled path p,

```text
s_p[n] = T_p(x_source(p)[n])
I_i[n] = sum(s_p[n] for enabled p with target(p) = i)
x_i[n+1] = x_i[n] + I_i[n]
```

An empty incoming sum is zero. Retention is exactly one. There is no automatic
decay, clipping, normalization, resetting, or asynchronous visibility. Feedback
cycles and self paths are legal and may amplify state until a bound is reached.
This rule is an intentionally small accumulator model, not a general physics law.

**Compute phase:** read only x[n]; compute every enabled signal, then all candidate
states. Incoming sums and arithmetic intermediates use unrestricted exact rational
arithmetic; the stated bounds apply to transformed signals and final candidate
states. This prevents temporary partial sums from causing order-dependent rejection.

**Commit phase:** only after every signal and candidate passes validation, construct
a new network at n+1 and append one snapshot. No input network is mutated. On any
failure, no successor is returned and the old state, clock, and history remain intact.

Realm and path declarations, snapshots, and printed histories are sorted by
case-sensitive `string<` IDs. Execution can be deliberately permuted using
`step-network`'s `:realm-order` and `:path-order` lists. Each non-NIL list must be an
exact permutation of all corresponding IDs, including disabled paths. NIL selects
the default order. Exact arithmetic and previous-state reads make the resulting
states and canonical history independent of these traversal orders. The executable
suite checks all 6*6 orders of the three-realm interaction fixture over four ticks.

## 5. Snapshots, histories, and ownership

`network-snapshot` returns `(:tick n :states ((id state) ...))`. `network-history`
returns a chronological list including tick 0 and every committed successor.
Both return fresh list trees and copied identifier strings. `realm-children`
returns fresh immediate-child IDs; `realm-state` returns an immutable rational.
Inputs are copied at declaration/assembly boundaries. Modifying returned snapshots
or input strings cannot change the engine's committed state.

Histories record states, not a self-contained serialization of topology or operator
coefficients. Reproduction therefore requires the declarations recorded in the
experiment source as well as the history. No checkpoint loader, runtime topology
editing, self-modification, or concurrent mutation API exists. The supported API is
the exported interface; direct modification of internal package objects is unsupported.

## 6. Public API and rejected conditions

```lisp
(make-realm "a" :state 3 :parent nil)
(make-path "ab" "a" "b" :operator :affine :gain 2 :offset 1 :enabled t)
(make-network realm-declarations path-declarations)
(realm-state network "a")
(realm-children network "container")
(transform-signal path 3)
(step-network network :realm-order nil :path-order nil)
(run-network network 4)
(network-tick network)
(network-snapshot network)
(network-history network)
(print-network-history network stream)
```

Network creation requires finite proper declaration lists, at least one realm,
correct declaration types, unique IDs, existing parents/endpoints, acyclic
containment, and lawful path boundaries. Malformed topology, unknown realm reads,
invalid numerical inputs, unsupported operators/coefficient combinations, invalid
enabled flags, out-of-bound signals or next states, invalid execution permutations,
and invalid step counts signal the exported `model-error` condition. Step counts
must be nonnegative integers. Standard Common Lisp arity and unknown-keyword errors
remain standard language errors. No invalid operation is silently repaired.

## 7. Controlled Experiment 001

All cases use fixed declarations and no randomness. Source and human-readable
recorded results reside in `experiments/001/`.

| Case | Controlled question | Prespecified observation |
| --- | --- | --- |
| A | Does an affine path transform a signal correctly? | a=3, b=0; T(x)=2x+1; b[1]=7, a[1]=3 |
| B | Does a recurrent network follow the recurrence? | a'=a+c/2, b'=b+2a, c'=c+3b from (1,0,0); tick 4=(13,14,36) |
| C | Does a boundary require explicit traversal? | input=1, shell=inner=0; input->shell->inner; inner[1]=0, inner[2]=1, inner[3]=3 |
| D | Are repeated histories identical? | two fresh copies of B yield identical complete histories |
| E | Does disabling bc have the predicted effect? | from B, disable only b->c; c remains 0, a remains 1, b[4]=8 |
| F | Are malformed/unsupported conditions rejected? | each listed negative case raises model-error |

Observations are printed before a separately labeled interpretation. Validation
counts identify passed, failed, and unexecuted comparisons. A failed comparison
causes a nonzero process exit. Unexpected runtime errors also abort execution.

## 8. Future research and explicit exclusions

**Resonance as a mechanism inside a recursive realm network remains a future
research hypothesis.** Any such implementation must follow acoustic laws and
specify its coupling, medium or lumped approximation, damping, forcing, and energy
accounting. The prior acoustic baseline is retained separately in `src/acoustics.lisp`
and `docs/ACOUSTICS.md`; no coupling to the rational realm engine is implemented.
It does not establish resonance between unconnected realms.

**Fractalization remains a future research hypothesis.** Finite recursive containment
is implemented; scale invariance, self-similar generative rules, and any benefit of
fractal organization are neither implemented nor established.

There are no claims or mechanisms for emergent intelligence, consciousness,
subjective experience, unspecified metaphysics, autonomous self-modification,
financial prediction, or unmeasured performance/scalability. Exact arithmetic is
chosen for falsifiable small experiments; unrestricted intermediate arithmetic,
linear lookup, and retained histories impose resource costs that are not benchmarked.

# SEPHIRION-002: acoustic resonance across recursive realms

Protocol date: 2026-11-18. This specification, including the tolerances below,
was written before evaluating the new implementation. Parameters are normalized
reference values, not measurements or calibration of physical hardware.

## Separate state model

The `sephirion-acoustic` package implements floating-point acoustic realms.
SEPHIRION-001's exact-rational accumulator, public API, specification, and recorded
results remain unchanged. Its scalar state is never interpreted as acoustic energy.
Directed signal paths do not become physical acoustic couplings.

An acoustic realm has a nonempty, case-sensitive unique string ID, an optional
immediate parent ID, displacement q, velocity v, positive inertance M and inverse
compliance K, nonnegative resistance R, and an explicit pressure excitation
`F(t) = A cos(omega*t + phase)`. A defaults to zero (unforced); omega may be zero
for constant pressure. Negative drive amplitude and phase are allowed. q and v
default to zero. Coefficients and state are represented as double floats.

q is volume displacement, v is volume velocity. In SI the corresponding units
are m^3, m^3/s, M [Pa s^2/m^3], K [Pa/m^3], R [Pa s/m^3], and F [Pa].
The reference runs use normalized units and angular frequency in inverse reference
time, not Hz. All nodes, including containers, are explicit physical degrees of
freedom with their own positive M and K. No massless or invisible container is added.

## Passive acoustic interaction and containment

An undirected coupling has a unique ID, two distinct existing endpoint IDs, a
nonnegative stiffness Kij, and a Boolean enabled flag. It represents one ideal
linear elastic acoustic compliance storing `Kij*(qi-qj)^2/2`. It is a specified
lumped interaction, not a simulation of a spatial sound field, propagation delay,
radiation, nonlinear acoustics, or an unspecified medium. Its force on the two
endpoints is equal and opposite, so Kij = Kji by construction.

Only one coupling per unordered endpoint pair is accepted, including disabled
couplings. Duplicate IDs, self couplings, directed path objects, negative
coefficients, and arbitrary drive callbacks are rejected. Kij=0 and disabled
couplings contribute no force and store no energy, but their topology is validated.

Containment reuses SEPHIRION-001's forest validation and boundary rules: couplings
join siblings (including roots) or an immediate parent/child. Missing parents,
cycles, and boundary bypasses fail even for a disabled edge. Containment alone
creates no force, energy, or aggregation. An acoustic node may interact with its
descendants only through explicitly declared lawful couplings. This continuous
ODE model has no artificial one-tick transmission delay: all connected coordinates
are advanced together at every RK4 stage. This differs explicitly from rational
signal propagation in SEPHIRION-001.

## Equations and energy derivation

For each i, with each active coupling counted once as an unordered edge:

```text
dqi/dt = vi
Mi dvi/dt = Fi(t) - Ri vi - Ki qi - sum_j Kij(qi-qj)

Elocal_i = (Mi vi^2 + Ki qi^2)/2
Eedge_ij = Kij(qi-qj)^2/2
Etotal = sum_i Elocal_i + sum_edges Eedge_ij
```

Differentiate local energy and substitute the force equation:

```text
d(sum Elocal)/dt = sum Fi vi - sum Ri vi^2
                  - sum_edges Kij(qi-qj)(vi-vj)
d(sum Eedge)/dt  = + sum_edges Kij(qi-qj)(vi-vj)
dEtotal/dt      = Pin - Ploss
Pin = sum Fi vi; Ploss = sum Ri vi^2 >= 0
W(t) = integral_0^t Pin ds; D(t) = integral_0^t Ploss ds
residual(t) = Etotal(t) - Etotal(0) - W(t) + D(t)
```

Thus unforced, undamped dynamics conserve E in the differential equations;
unforced damped dynamics cannot increase it. Numerical residuals test whether the
discretization follows this law. Each realm's reported energy contribution is its
local energy plus **half each incident edge energy**. These contributions sum to
Etotal; the half allocation is an accounting convention, not unique localization
of the acoustic field. Both local and allocated energy are recorded. In transfer
experiments, use the initially unexcited receiver's local energy, avoiding an
apparent initial transfer caused by allocating spring energy.

## Integration, numerical constraints, and observations

Use classical RK4 on the entire vector `(q1,v1,...,qN,vN,W,D)`. Both work and loss
integrals use the same intermediate states and times as the mechanical variables;
no low-order endpoint quadrature is substituted. A fixed positive dt and integer
tick define time=tick*dt. Compute a successor fully before returning it; the input
network remains unchanged on success or failure. States and snapshots are copied.
Canonical string-ID ordering makes construction order reproducible. No claim of
bitwise portability between Lisp implementations or machines is made.

Finite real inputs are converted to double floats. Input magnitudes and integrated
components must be <=1e100. Positive M and K must be >=1e-100. Nonfinite values,
complex values, unsupported types, invalid lists, invalid step counts, and invalid
dt are rejected with `sephirion:model-error`. Floating-point arithmetic failures
are reported as model errors rather than returning a partial successor. Advancing
must increase representable time. There is no adaptive stability guarantee or
automatic timestep repair; new coefficient ranges need new convergence studies.

The positive dt and response-measurement frequency are also required to be at
least 1e-100. Individual realm drive frequencies may be zero. The response
measurement helper requires fresh rest states, the requested dt, and the same
drive frequency on all realm declarations (including unforced nodes). General
stepping supports separately declared harmonic or constant excitations per node.

Snapshots expose tick, time, per-realm q/v/force/local and allocated energies,
instantaneous input/loss power, Etotal, W, D, and residual. The engine does not retain
all snapshots in memory. Experiments write CSV traces at a declared cadence,
including tick 0 and the final tick. Sweep output records complex-response amplitude
and principal phase [-pi,pi], means of stored energy, energy/work/loss at the end,
and maximum residual over the entire run, including settling. A phase near zero
amplitude is not interpreted as evidence of interaction.

## Experiment protocol

The exported interface is in package `sephirion-acoustic`:

| Function | Meaning |
| --- | --- |
| `make-acoustic-realm id &key parent q v m k r amplitude omega phase` | Explicit immutable initial-state and physical-parameter declaration |
| `make-coupling id a b stiffness &key enabled` | One symmetric passive compliance between two endpoints |
| `make-acoustic-network realms couplings &key dt` | Validate, copy, canonically order, and initialize the physical network |
| `step-acoustic network` | Return the synchronous RK4 successor without changing its predecessor |
| `run-acoustic network steps` | Return the successor after a nonnegative integer number of steps |
| `acoustic-state network` | Copy of the vector `(q1 v1 ... qN vN W D)`, in sorted realm-ID order |
| `acoustic-energy network`, `acoustic-snapshot network` | Total stored energy and a fresh detailed observation |
| `write-trace-header stream`, `write-trace-row network stream` | Portable CSV recording |
| `measure-acoustic-response factory omega &key settle-time cycles max-dt trace-stream trace-stride` | Fresh-run response and energy measurements; factory receives the actual dt |

Internal structures are not a supported mutation interface. Snapshots and raw
state vectors do not include a complete replayable topology/parameter manifest;
the recorded fixture declarations supply those parameters. There is no coupling
from acoustic state back into the exact-rational accumulator in this milestone.

Configuration A: two realms, M=K=1, R=0.2, coupling=0.5, unit cosine drive on a.
Recover the old pair integrator and its independently computed frequency-domain
response. Additional asymmetric coefficients are tested to expose indexing errors.

Configuration B: chain a--b--c, M=K=1, R=0.2, both couplings=0.5, unit drive on a.
Measure the response at every node. Independently compare the uniform chain with
its normal modes: vectors proportional to (1,1,1), (1,0,-1), (1,-2,1), stiffness
eigenvalues 1, 1+Kc, 1+3Kc. The complex response is the sum of these orthogonal
modal responses under the applied drive.

Configuration C: the same chain and three degrees of freedom, but a is the root
container and b,c its children. a--b is parent/child and b--c sibling coupling.
For the flat control all parents are NIL. No other physical parameter changes.
Expected null: identical trajectories and measured responses. Check the whole
trajectory, not only a final state. A no-edge nested control must stay unexcited
outside its explicitly driven node.

Driven sweeps: omega=0.5..2.0 inclusive, spacing 0.05 (31 frequencies). Every run
starts from rest; discard at least 400 reference time units and project eight
complete drive cycles onto exp(-i omega t). The period is divided into at least
32 steps, with dt<=0.02. Amplitude is twice the modulus of the projection mean;
phase is its argument. Pair controls vary one parameter at a time:

| Scenario | Coupling | R1=R2 | K2 (K1=1) |
| --- | --- | --- | --- |
| pair-reference | 0.5 | 0.2 | 1 |
| pair-off | 0 (disabled) | 0.2 | 1 |
| pair-weak | 0.1 | 0.2 | 1 |
| pair-mismatch | 0.5 | 0.2 | 2.25 |
| pair-low-damping | 0.5 | 0.1 | 1 |
| pair-high-damping | 0.5 | 0.5 | 1 |

Also sweep the flat and nested reference chains. Define a **sampled resonant peak**
operationally as an interior sample with larger amplitude than both neighbors,
with the same fixed drive amplitude and all other parameters held fixed. Report
the largest sampled response separately. Grid maxima are not fitted resonant
frequencies. Frequencies matching in isolation do not constitute transfer.

Free-transfer controls: pair initially q_a=1, all other q/v=0, no drive/damping;
Kc=0,0.1,0.5; dt=0.02 for 40 units. Record max receiver local energy/Einitial,
and first sampled time it reaches 10% of Einitial, if any. These are finite-window
metrics, not a universal claim of monotonic transfer versus coupling strength.

Traces: record free-transfer runs every 10 steps and the nested driven chain at
omega=1 every 10 steps, including its settling interval. Raw integration still
uses every step. All other driven runs record their response and energy summaries.

## Prespecified validation thresholds

| Check | Acceptance criterion for the stated fixtures |
| --- | --- |
| Pair transient recovery | maximum q/v difference from old RK4 <1e-11 over 1000 steps at dt=0.02 |
| Pair and chain analytical responses | absolute complex response error <5e-6 at each measured node/frequency |
| Uncoupled isolation | undriven initial-rest nodes remain exactly zero |
| Unforced undamped energy | max relative drift <1e-7 over 100 units, dt=0.02 |
| Passive decay | no per-step increase >1e-12; E(20)<0.03 E(0) for R=0.2 |
| Driven work/loss balance | max abs residual/(1+Einitial+abs(W)+D) <1e-6 |
| Timestep refinement | q/v error ratio >12 when halving dt=0.08 to 0.04 against an exact in-phase free mode at t=10 |
| Driven balance refinement | maximum residual improves by factor >8 for dt=0.08 to 0.04 over 20 units |
| Steady-state settling | response at 400 vs 600 discarded time units differs by <5e-6 for the least-damped reference pair |
| Determinism | identical histories/output on repeated runs in the same runtime |
| Flat vs nested | exactly equal floating-point physical state at every tick when only containment labels differ |
| Invalid input and boundaries | explicit model-error; predecessor unchanged after failed stepping |
| SEPHIRION-001 regression | all existing tests pass; recorded Experiment 001 output unchanged |

Thresholds apply to the specified finite fixtures, not every possible parameter
set. Failed validations must retain their evidence and must not be hidden by
relaxing thresholds after observing data. Unexpected failures block a success claim.

## Scientific limits

The model investigates specified lumped acoustic mechanisms in a recursive
organization. It does not establish spatial propagation, physically calibrated
apparatus, fractalization, emergent intelligence, cognition, consciousness,
metaphysical resonance, or interactions between unconnected realms. Q4's expected
null would show that this model's behavior is explained by the explicit graph;
it is not evidence against all possible future recursive models.

# Acoustic baseline: experiment 0001

Resonance in SEPHIRION follows acoustic laws. It requires an explicit physical
coupling model; a shared frequency alone cannot transmit energy.

This baseline is a linear lumped acoustic analogue, with two resonators and a
passive elastic coupling. It does not yet model a spatial medium, propagation
delay, radiation, geometry, nonlinear acoustics, recursive realms, or cognition.
The coefficients are normalized reference values, not measurements of an apparatus.

## State and equations

For resonator i, q_i is volume displacement and u_i = dq_i/dt is volume velocity.
M_i is acoustic inertance, R_i is resistance, K_i = 1/C_i is inverse compliance.
Kc is the inverse compliance of an elastic coupling. Input pressure is
p(t) = P cos(omega t), applied only to resonator 1.

```text
M1 q1'' + R1 q1' + K1 q1 + Kc(q1 - q2) = P cos(omega t)
M2 q2'' + R2 q2' + K2 q2 + Kc(q2 - q1) = 0
```

In physical SI units: q [m^3], u [m^3/s], p [Pa], M [Pa s^2/m^3],
R [Pa s/m^3], K and Kc [Pa/m^3]. The reference run uses normalized units;
its frequencies are angular frequencies in inverse reference time, not Hz.

M and K must be positive; R and Kc must be nonnegative. The coupling forces are
equal and opposite. Both resonators update together using classical fourth-order
Runge-Kutta (RK4), including the drive at each intermediate stage.

```text
E = (M1 u1^2 + M2 u2^2 + K1 q1^2 + K2 q2^2 + Kc(q1-q2)^2) / 2
dE/dt = p(t) u1 - R1 u1^2 - R2 u2^2
```

Without drive or damping, energy is conserved in the differential equations.
With damping and no drive, it decreases. The integrator approximates these laws;
numerical error must be measured rather than interpreted as emergent behavior.

## Independent frequency-domain reference

Use q_i(t) = Re(Q_i exp(i omega t)). A negative phase is a lag relative to pressure.

```text
Z1 = K1 + Kc - M1 omega^2 + i R1 omega
Z2 = K2 + Kc - M2 omega^2 + i R2 omega
D = Z1 Z2 - Kc^2
Q1 = P Z2 / D
Q2 = P Kc / D
```

The reference pair has M1=M2=K1=K2=P=1, R1=R2=0.2, Kc=0.5.
Its undamped normal-mode angular frequencies are 1 and sqrt(2). Damped forced
response maxima need not occur at those exact frequencies, and depend on the
drive and measurement location.

## Reproduction and measurements

```sh
sbcl --script scripts/test.lisp
sbcl --script scripts/experiment-0001.lisp
```

Each of 61 frequencies from 0.5 through 2.0 (spacing 0.025) starts from rest.
Discard 200 reference time units, then measure eight complete drive cycles.
The timestep divides the drive period into an integer number of steps and never
exceeds 0.02. Complex amplitudes are twice the mean of q(t) exp(-i omega t)
over those eight cycles. Numerical results are compared to the independent
frequency-domain solution, not initialized from it.

`reports/experiment-0001/sweep.csv` records amplitudes, phases (radians), analytical
values, absolute complex errors, and actual timesteps. `trace.csv` records every
tick, including initial state and settling, at omega=1, with state, energy, and
instantaneous power. Re-running replaces these two files.

Phases use the principal angle in [-pi, pi]. The plotted jump across that boundary
is phase wrapping, not a discontinuity in the physical response.

The automated checks cover uncoupled isolation, analytical response including
asymmetric resonators, undamped energy conservation, passive decay, energy/work
balance, and timestep convergence against an exact free oscillation. The fixed
settling time and timestep are validated for this reference experiment only;
new coefficients require new convergence and transient checks. Undamped driven
resonance has no bounded steady state; the analytical solver rejects singular cases.

## References

- [Penn State: Acoustics and Vibration Animations](https://www.acs.psu.edu/drussell/demos.html): forced oscillation, damping, and coupled energy transfer.
- [On the physical origin of the electro-mechano-acoustical analogy](https://doi.org/10.1121/10.0009803): acoustic inertance, compliance, resistance, and their mechanical analogues.

This experiment validates implementation of a specified linear model. It does
not establish physical calibration, recursive architectural benefits, or emergence.

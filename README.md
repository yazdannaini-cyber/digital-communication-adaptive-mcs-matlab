# Modular Digital Communication System Simulation & Adaptive Link Control

**MATLAB | Digital Communications | Channel Coding | Channel Estimation | Adaptive MCS/FEC**

## Overview

This repository contains a modular MATLAB link-level simulation project for studying digital modulation, channel coding, fading channels, packet reliability, pilot-aided channel estimation, interleaving, and empirical link-adaptation policies.

The implementation is research/portfolio-oriented. It provides reproducible simulation scripts and stored result tables, while explicitly documenting assumptions and limitations. It is **not** a certified LTE/5G NR physical-layer implementation.

## Implemented capabilities

### Modulation and reception

- BPSK, QPSK, and 16-QAM.
- Gray-coded constellation mappings.
- Soft-output LLR demapping.
- Coherent equalization.

### Channel models

- AWGN.
- Flat Rayleigh and Rician fading.
- Block-fading links with four fading blocks per packet in the relevant experiments.
- Perfect-CSI reference reception.
- Pilot-based least-squares (LS) channel estimation for block fading.

### Channel coding

- CRC-16/CCITT-FALSE.
- Hamming (7,4).
- Rate-1/2 convolutional coding with constraint length 3 and generators (7,5), with two zero-tail bits in the implemented encoder.
- Hard- and soft-decision Viterbi decoding.
- Custom systematic rate-1/2 LDPC code, N=128 and K=64, decoded using normalized min-sum.
- Polar code, N=128 and K=64, using Bhattacharyya-parameter construction and successive-cancellation (SC) decoding.

The LDPC parity-check matrix and Polar construction are project-specific short-block designs. They are not the standardized 5G NR LDPC or Polar constructions.

### Interleaving and link adaptation

- Block interleaver and deinterleaver.
- Adaptive interleaver-depth selection.
- Empirical QoS-aware adaptive MCS policy for BPSK, QPSK, and 16-QAM.
- Offline AWGN adaptive FEC policy comparing uncoded BPSK, convolutional/Viterbi, LDPC, and Polar.

The adaptive FEC policy is an empirical SNR lookup policy derived from the stored AWGN comparison dataset. It is not yet an online, end-to-end FEC-switching transmitter/receiver implementation and has not been independently validated on a held-out dataset.

## Main project experiments

| Experiment | Main script | Main outputs |
|---|---|---|
| MCS calibration | `main_mcs_profile_calibration.m` | `results/mcs_profile_calibration.*` |
| Adaptive MCS policy | `main_build_adaptive_mcs_policy.m` | `results/adaptive_mcs_policy.*` |
| Independent MCS validation | `main_validate_adaptive_mcs_policy.m` | `results/adaptive_mcs_validation.*` |
| Deep boundary validation | `main_boundary_mcs_validation.m` | `results/boundary_mcs_validation.*` |
| Corrected paired boundary statistics | `main_recompute_boundary_pairwise.m` | `results/boundary_mcs_pairwise_comparison.csv` |
| Pilot-aided CSI validation | `main_pilot_based_csi_validation.m` | `results/pilot_csi_validation.*` |
| AWGN FEC comparison | `main_fec_awgn_comparison.m` | `results/fec_awgn_comparison.*` |
| Adaptive FEC policy | `main_build_adaptive_fec_policy.m` | `results/adaptive_fec_policy.*` |
| FEC figures | `plot_fec_awgn_comparison.m` | `results/figures/fec_awgn_*` |

## Selected experimental findings

### Adaptive MCS and boundary validation

- MCS calibration covered 108 profile/operating-point records: 2 channel models, 9 SNR points from 4 to 20 dB, 3 modulations, and 2 interleaver depths.
- Independent MCS validation covered the corresponding 108 profile records.
- A deeper validation used 3,000 packets for each of nine policy-selected boundary operating points.
- All nine selected boundary profiles met the configured criterion that the Wilson 95% upper confidence bound on PER be no greater than 0.20 in that deep validation run.
- Equal-depth paired QPSK-versus-16-QAM comparisons were evaluated at 18 channel/SNR/depth combinations. All 18 remained significant after Holm-Bonferroni correction in the stored experiment; QPSK had lower observed PER in every comparison.

### Pilot-aided channel estimation

- LS channel estimation was evaluated at nine selected operating points, with 3,000 packets per point.
- Each of four fading blocks used 16 known BPSK pilot symbols: 64 pilot symbols per packet.
- The reported average channel-estimation NMSE across the nine points was approximately -29.21 dB.
- Perfect-CSI reception met the PER target at 9/9 points; estimated-CSI reception met it at 8/9 points.
- The Rician 10 dB estimated-CSI point was marginally above the target by its 95% PER upper bound.

**Comparison caveat:** in the current pilot experiment, the estimated-CSI branch allocates part of the packet energy to pilots, while the Perfect-CSI reference branch uses no pilots and retains the data-only energy allocation. Therefore, the measured PER difference combines pilot-energy overhead and channel-estimation error; it does not isolate estimation error alone. The LLR noise-variance inflation is an approximation, not an exact likelihood model for uncertain channel estimates.

### FEC comparison over AWGN

The stored AWGN experiment used 48 payload bits, 16 CRC bits, BPSK, 1,000 packets per SNR point, and Eb/N0 values from 0 to 10 dB in 2 dB steps. The LDPC and Polar blocks used N=128, K=64. The convolutional encoder included its two tail bits, so its transmitted codeword length was 132 bits for the 64-bit payload-plus-CRC block.

Observed PER:

| Eb/N0 (dB) | Uncoded BPSK | Convolutional/Viterbi | LDPC/Normalized Min-Sum | Polar/SC |
|---:|---:|---:|---:|---:|
| 0 | 0.996 | 0.955 | 0.988 | 0.959 |
| 2 | 0.960 | 0.583 | 0.843 | 0.499 |
| 4 | 0.719 | 0.117 | 0.294 | 0.038 |
| 6 | 0.265 | 0.003 | 0.034 | 0.001 |
| 8 | 0.066 | 0.000 | 0.000 | 0.000 |
| 10 | 0.001 | 0.000 | 0.000 | 0.000 |

Zero observed packet errors at 8 and 10 dB do not imply a true PER of zero; with 1,000 packets, the Wilson upper confidence bound remains nonzero. At low SNR, the custom LDPC decoder required more iterations and had a lower convergence rate. The measured Polar-SC performance is specific to this short-block construction, design SNR, and SC decoder; it should not be generalized to standardized Polar implementations or list decoding.

### Offline adaptive FEC policy

With an empirical target of `PER_Upper95 <= 0.10`, the stored AWGN lookup policy selected:

| Eb/N0 (dB) | Selected scheme |
|---:|---|
| 0 | Convolutional/Viterbi |
| 2 | Polar/SC |
| 4 | Polar/SC |
| 6 | Polar/SC |
| 8 | Uncoded BPSK |
| 10 | Uncoded BPSK |

This policy was selected from the same AWGN dataset used to build the lookup table. It is a proof-of-concept offline decision policy, not a held-out validation result.

## Metrics and statistical methods

- Payload BER and packet error rate (PER).
- CRC failure, CRC-only failure, and undetected packet error counters where implemented.
- Effective payload rate and correct-payload goodput/spectral-efficiency measures.
- Wilson 95% confidence intervals for packet error probability.
- Exact two-sided McNemar tests for paired packet outcomes.
- Holm-Bonferroni correction for multiple comparisons.
- LDPC iteration count and syndrome-based convergence diagnostics.
- Channel-estimation NMSE and pilot overhead.

## Reproduction workflow

Run MATLAB from the repository root and add the project folders to the path:

```matlab
addpath(genpath(pwd));
rehash;
```

Examples:

```matlab
% Validate LDPC and Polar encoder/decoder implementations
run(fullfile(pwd,'tests','test_ldpc_polar_coding.m'));

% Run the AWGN FEC comparison
main_fec_awgn_comparison

% Validate FEC comparison outputs
run(fullfile(pwd,'tests','test_fec_awgn_comparison.m'));

% Build and test the offline adaptive FEC policy
main_build_adaptive_fec_policy
run(fullfile(pwd,'tests','test_adaptive_fec_policy.m'));

% Rebuild FEC plots from saved results without rerunning Monte Carlo
plot_fec_awgn_comparison
```

Other test scripts are located under `tests/`. Some experiments are computationally heavier; use their saved `.mat` and `.csv` outputs for analysis when available.

## Assumptions and limitations

- Perfect CSI is used in the reference adaptive-MCS and boundary experiments.
- The LS pilot experiment assumes a constant complex channel coefficient within each fading block and known pilot symbols at the receiver.
- The current fading experiments use a simplified block/flat-fading model, not a complete time- or frequency-selective standardized channel model.
- The FEC comparison is an AWGN/BPSK experiment with short blocks; it does not establish universal ranking of code families.
- The Polar reliability sequence is generated using a Bhattacharyya approximation at a configured design SNR, not an official 5G reliability sequence.
- The LDPC parity-check matrix is a custom sparse construction, not a standardized base graph or rate-matched NR code.
- Processing times measured in MATLAB are software benchmarks, not hardware or end-to-end link latency guarantees.
- Pilot signaling, channel-estimation error, and control signaling overhead are not yet integrated into one unified adaptive MCS/FEC link controller.

## Future work

- Integrate the FEC choices into a single end-to-end adaptive transmitter/receiver.
- Validate adaptive FEC on independent, held-out AWGN and fading datasets.
- Improve Polar decoding with CRC-aided successive-cancellation list (SCL) decoding.
- Compare additional LDPC constructions and decoder schedules.
- Add pilot-based channel estimation to adaptive MCS experiments and quantify CSI uncertainty more rigorously.
- Add practical SNR estimation and adaptive control-signaling overhead.
- Explore standardized 5G NR LDPC/Polar chains and rate matching.

## License

See `LICENSE`. Ensure that all source code and assets committed to this repository are your own or are included under compatible licenses.

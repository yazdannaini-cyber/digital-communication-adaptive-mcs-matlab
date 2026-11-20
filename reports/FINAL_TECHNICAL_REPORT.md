# Final Technical Report

## 1. Scope

This report summarizes the MATLAB digital-communication simulation project, including modulation, channel coding, adaptive MCS, pilot-aided channel estimation, and AWGN FEC experiments.

## 2. Modulation and link components

The implemented link modules include BPSK, QPSK, and 16-QAM; AWGN, Rayleigh, and Rician fading; coherent equalization; soft-output demapping; CRC-16; convolutional coding and Viterbi decoding; and block interleaving.

## 3. Adaptive MCS evaluation

The MCS calibration campaign covered 108 records across two channel types, nine Eb/N0 values from 4 to 20 dB, three modulation formats, and two interleaver depths. An independent validation campaign used new payload, fading, and noise realizations. Nine policy-selected boundary operating points were then evaluated with 3,000 packets per point. All nine selected profiles met the pre-defined PER criterion based on a Wilson 95% upper confidence bound no greater than 0.20 in the deep validation run.

At equal interleaver depths, the stored paired comparisons found lower observed PER for QPSK than 16-QAM across all 18 tested channel/SNR/depth combinations. All 18 comparisons remained significant after Holm-Bonferroni correction. This result is limited to the tested short-block link, channel models, SNR points, and simulation settings.

## 4. Pilot-aided channel estimation

The LS estimator was evaluated using 16 known BPSK pilots at the start of each of four block-fading segments, or 64 pilots per packet. Each of nine selected operating points used 3,000 packets. The average of the reported pointwise NMSE values in dB was approximately -29.21 dB. Perfect-CSI reception met the configured PER target at 9/9 points; the estimated-CSI branch met it at 8/9 points.

The Rician 10 dB estimated-CSI point had a PER upper confidence bound of 0.20443, just above the 0.20 target. The current comparison does not isolate channel-estimation error alone: the estimated-CSI branch spends part of the packet energy on pilot symbols, while the Perfect-CSI reference does not. Thus the measured degradation combines pilot-energy allocation and estimation uncertainty. The receiver uses an approximate LLR noise-variance inflation factor rather than an exact uncertain-CSI likelihood.

## 5. LDPC and Polar implementation

A custom systematic LDPC code with N=128 and K=64 was implemented using a sparse parity-check matrix and a normalized min-sum decoder. The decoder uses a maximum of 20 iterations and normalization factor 0.8 in the AWGN comparison.

A Polar code with N=128 and K=64 was implemented using a Bhattacharyya-parameter reliability construction at a design Eb/N0 of 2 dB and a recursive successive-cancellation decoder using a min-sum approximation for the check-node function.

These are project-specific educational/research implementations. Neither implementation is claimed to be a standardized 5G NR LDPC or Polar chain.

## 6. AWGN FEC comparison

The AWGN comparison used 48 payload bits, 16 CRC bits, BPSK, 1,000 packets per SNR value, and Eb/N0 values 0, 2, 4, 6, 8, and 10 dB. Total transmitted packet energy was normalized to the 48 information payload bits. Convolutional packets included two zero-tail input bits, resulting in 132 transmitted coded bits for the 64-bit payload-plus-CRC block. LDPC and Polar transmitted 128 coded bits.

| Eb/N0 (dB) | Uncoded BPSK PER | Convolutional/Viterbi PER | LDPC/Min-Sum PER | Polar/SC PER |
|---:|---:|---:|---:|---:|
| 0 | 0.996 | 0.955 | 0.988 | 0.959 |
| 2 | 0.960 | 0.583 | 0.843 | 0.499 |
| 4 | 0.719 | 0.117 | 0.294 | 0.038 |
| 6 | 0.265 | 0.003 | 0.034 | 0.001 |
| 8 | 0.066 | 0.000 | 0.000 | 0.000 |
| 10 | 0.001 | 0.000 | 0.000 | 0.000 |

The custom Polar-SC implementation had the lowest measured PER at 2–6 dB in this experiment. The convolutional code had the lowest PER at 0 dB and remained competitive at 6 dB. The LDPC decoder exhibited low convergence at very low SNR, rising to 95.5% at 6 dB and 100% at 8 and 10 dB in the recorded run. Zero observed packet errors at high SNR do not imply zero true PER; confidence bounds remain nonzero.

## 7. Empirical adaptive FEC policy

An offline policy with a target Wilson PER upper bound of 0.10 selected Convolutional/Viterbi at 0 dB, Polar/SC at 2, 4, and 6 dB, and Uncoded BPSK at 8 and 10 dB. This is a lookup policy built from the same AWGN dataset used in its selection. It has passed the policy logic tests but has not yet undergone independent held-out validation or end-to-end adaptive code switching.

## 8. Statistical methods

Packet error confidence intervals use the Wilson method. Paired binary packet outcomes are compared using an exact two-sided McNemar test. Multiple comparisons are adjusted with the Holm-Bonferroni procedure.

## 9. Limitations

- Perfect CSI remains the reference assumption in the adaptive-MCS boundary experiments.
- The pilot experiment uses block-constant channels and an approximate LLR uncertainty correction.
- The channel models are simplified link-level models, not complete standardized LTE/5G channel models.
- LDPC and Polar constructions are custom short-block designs.
- The offline adaptive FEC policy has not been independently validated.
- MATLAB timing measurements are not hardware latency guarantees.

## 10. Conclusion

The project demonstrates a modular MATLAB communication simulation environment with coding, fading, channel-estimation, adaptive-MCS, and statistical-evaluation capabilities. The results support a clear reliability/spectral-efficiency trade-off between QPSK and 16-QAM in the tested configurations and provide a baseline for future standardized LDPC/Polar, SCL, and end-to-end adaptive FEC work.

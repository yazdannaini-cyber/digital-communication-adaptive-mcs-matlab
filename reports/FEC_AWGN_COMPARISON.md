# FEC Comparison over AWGN

## Configuration

- Payload: 48 bits
- CRC: 16 bits
- Encoded input block: 64 bits
- Modulation: BPSK
- Channel: AWGN
- Eb/N0: 0:2:10 dB
- Packets per SNR: 1,000
- LDPC: N=128, K=64, normalized min-sum, alpha=0.8, max 20 iterations
- Polar: N=128, K=64, Bhattacharyya construction at 2 dB, SC decoder
- Convolutional: rate 1/2, generators (7,5), two zero-tail bits
- Total packet energy normalized to 48 payload-bit energy units

## Packet error rate

| Eb/N0 (dB) | Uncoded BPSK | Convolutional/Viterbi | LDPC/Min-Sum | Polar/SC |
|---:|---:|---:|---:|---:|
| 0 | 0.996 | 0.955 | 0.988 | 0.959 |
| 2 | 0.960 | 0.583 | 0.843 | 0.499 |
| 4 | 0.719 | 0.117 | 0.294 | 0.038 |
| 6 | 0.265 | 0.003 | 0.034 | 0.001 |
| 8 | 0.066 | 0.000 | 0.000 | 0.000 |
| 10 | 0.001 | 0.000 | 0.000 | 0.000 |

## Decoder observations

- LDPC mean iteration count decreased from approximately 19.90 at 0 dB to 1.01 at 10 dB.
- LDPC convergence rate increased from 1.0% at 0 dB to 100% at 8 and 10 dB.
- Polar-SC gave the lowest measured PER at 2, 4, and 6 dB in this particular custom short-block experiment.
- Convolutional/Viterbi performed best among the coded options at 0 dB in the recorded results.
- At 8 and 10 dB, zero packet errors were observed for all three coded schemes; the finite sample size does not establish zero underlying PER.

## Interpretation and limitations

These observations apply only to the specified code constructions, decoder algorithms, short block length, BPSK/AWGN setup, energy normalization, and sample size. They do not establish a universal ranking of LDPC, Polar, and convolutional codes. The Polar decoder is SC rather than CRC-aided SCL. The LDPC matrix is custom and is not a 5G NR base-graph/rate-matching implementation.

## Offline adaptive FEC lookup policy

Using a Wilson PER upper-bound target of 0.10, the stored policy selected:

| Eb/N0 (dB) | Selected scheme |
|---:|---|
| 0 | Convolutional/Viterbi |
| 2 | Polar/SC |
| 4 | Polar/SC |
| 6 | Polar/SC |
| 8 | Uncoded BPSK |
| 10 | Uncoded BPSK |

The policy is trained/selected from the same measured AWGN table. It requires held-out validation before being represented as a validated adaptive FEC controller.

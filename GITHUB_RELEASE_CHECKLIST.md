# GitHub Release Checklist

## Before publishing

- [ ] Copy `README.md` to the repository root.
- [ ] Copy `.gitignore` to the repository root.
- [ ] Copy `LICENSE` to the repository root and replace `[Your Name]` with the copyright holder you choose.
- [ ] Copy `reports/FINAL_TECHNICAL_REPORT.md` and `reports/FEC_AWGN_COMPARISON.md` into the local `reports/` folder.
- [ ] Ensure `src/`, `config/`, `tests/`, root-level experiment scripts, and the intended `results/` CSV/MAT/PNG artifacts are present.
- [ ] Remove personal paths, machine-specific settings, credentials, tokens, and private files from the repository.
- [ ] Keep generated result files that are useful for reproducibility; inspect file sizes before committing.
- [ ] Confirm that the README accurately distinguishes custom LDPC/Polar implementations from 5G NR-standardized chains.
- [ ] Confirm that the offline adaptive FEC policy is described as not yet independently validated.

## Suggested repository metadata

**Repository name:** `digital-communication-adaptive-mcs-matlab`

**Description:** `MATLAB link-level simulation of digital modulation, channel coding, pilot-aided CSI estimation, and QoS-aware adaptive MCS/FEC policies.`

**Topics:** `matlab`, `digital-communications`, `channel-coding`, `ldpc`, `polar-codes`, `viterbi`, `rayleigh-fading`, `rician-fading`, `adaptive-modulation`, `channel-estimation`

## Local Git commands

Run these commands from the project root after copying the documentation files:

```bash
git init
git add .
git status --short
```

Inspect the staged files. Do not proceed until no private files, machine-specific paths, credentials, or unintended large files are staged.

```bash
git commit -m "Initial release: digital communication and adaptive link simulation"
git branch -M main
```

Create an empty GitHub repository with the suggested name, without generating a README, license, or .gitignore on GitHub (those files are already local). Then connect and push:

```bash
git remote add origin https://github.com/<YOUR_GITHUB_USERNAME>/digital-communication-adaptive-mcs-matlab.git
git push -u origin main
```

## Suggested release

**Tag:** `v1.0.0`

**Title:** `v1.0.0 — MATLAB Digital Communication Simulation`

**Release notes:**

- Modular BPSK/QPSK/16-QAM link simulation.
- AWGN, Rayleigh and Rician channel experiments.
- CRC-16, Hamming, convolutional/Viterbi, custom LDPC and Polar-SC coding modules.
- Adaptive MCS calibration and independent boundary validation.
- Pilot-based LS channel estimation experiments.
- AWGN FEC comparison and empirical offline adaptive FEC lookup policy.
- Statistical evaluation using Wilson confidence intervals, exact McNemar tests, and Holm-Bonferroni correction.

State the modeling limitations in the release description: custom short-block LDPC/Polar constructions, Perfect-CSI assumptions in selected experiments, simplified block-fading models, and the offline/non-held-out status of the adaptive FEC lookup policy.


clc;
clear;
close all;

%% =========================================================
% FINAL PROJECT PACKAGING AND AUDIT
%% =========================================================

projectRoot = fileparts(mfilename('fullpath'));

addpath(genpath(projectRoot));
rehash;

fprintf('\n=============================================\n');
fprintf(' FINAL PROJECT AUDIT\n');
fprintf('=============================================\n');

%% 1. Required result files

requiredFiles = {
    'results/mcs_profile_calibration.mat'
    'results/adaptive_mcs_policy.mat'
    'results/adaptive_mcs_validation.mat'
    'results/boundary_mcs_validation.mat'
};

missingFiles = {};

for k = 1:numel(requiredFiles)

    filePath = fullfile(projectRoot, requiredFiles{k});

    if exist(filePath,'file') ~= 2
        missingFiles{end+1} = requiredFiles{k};
    end

end

if ~isempty(missingFiles)

    fprintf('Missing files:\n');

    for k = 1:numel(missingFiles)
        fprintf(' - %s\n',missingFiles{k});
    end

    error('Project audit failed. Required files are missing.');

end

fprintf('Required result files: OK\n');

%% 2. Load final datasets

C = load(fullfile(projectRoot, ...
    'results','mcs_profile_calibration.mat'));

P = load(fullfile(projectRoot, ...
    'results','adaptive_mcs_policy.mat'));

V = load(fullfile(projectRoot, ...
    'results','adaptive_mcs_validation.mat'));

B = load(fullfile(projectRoot, ...
    'results','boundary_mcs_validation.mat'));

%% 3. Validate dataset dimensions

assert(height(C.ProfileTable) == 108, ...
    'Unexpected calibration table size.');

assert(height(P.AdaptivePolicy) == 18, ...
    'Unexpected adaptive policy size.');

assert(height(V.ValidationResults) == 108, ...
    'Unexpected independent validation size.');

assert(height(B.SelectedProfileValidation) == 9, ...
    'Unexpected selected boundary profile count.');

assert(height(B.PairwiseComparison) == 18, ...
    'Unexpected pairwise comparison count.');

fprintf('Calibration records       : %d\n',height(C.ProfileTable));
fprintf('Adaptive policy points    : %d\n',height(P.AdaptivePolicy));
fprintf('Independent test records  : %d\n',height(V.ValidationResults));
fprintf('Boundary validation points: %d\n',height(B.SelectedProfileValidation));
fprintf('Statistical comparisons   : %d\n',height(B.PairwiseComparison));

%% 4. Validate final QoS results

numQoSPassed = sum( ...
    B.SelectedProfileValidation.QoS_Met_Validation);

assert(numQoSPassed == 9, ...
    'Not all selected boundary profiles passed QoS.');

assert(all( ...
    B.SelectedProfileValidation.PER_Upper95 <= ...
    B.boundaryConfig.TargetPER), ...
    'Selected boundary profile violates QoS.');

fprintf('\nSelected profiles passing QoS: %d/9\n',numQoSPassed);

%% 5. Validate statistical findings

assert(all(B.PairwiseComparison.SignificantAfterHolm), ...
    'Some paired comparisons are not significant.');

assert(all(B.PairwiseComparison.DeltaPER_QAM16_minus_QPSK > 0), ...
    'Unexpected QPSK/16-QAM PER comparison result.');

fprintf('Significant paired comparisons: %d/18\n', ...
    sum(B.PairwiseComparison.SignificantAfterHolm));

%% 6. Create final directories

reportsDir = fullfile(projectRoot,'reports');

resultsDir = fullfile(projectRoot,'results');

if exist(reportsDir,'dir') ~= 7
    mkdir(reportsDir);
end

%% 7. Generate final metrics table

Metric = [
    "Calibration records"
    "Independent validation records"
    "Boundary selected profiles"
    "Boundary QoS successes"
    "Paired statistical comparisons"
    "Significant comparisons after Holm"
    "Target PER"
    "Boundary packets per profile"
];

Value = [
    string(height(C.ProfileTable))
    string(height(V.ValidationResults))
    string(height(B.SelectedProfileValidation))
    string(numQoSPassed)
    string(height(B.PairwiseComparison))
    string(sum(B.PairwiseComparison.SignificantAfterHolm))
    string(B.boundaryConfig.TargetPER)
    string(B.boundaryConfig.NumPackets)
];

FinalMetrics = table(Metric,Value);

writetable(FinalMetrics, ...
    fullfile(resultsDir,'final_project_metrics.csv'));

%% 8. Generate README

readme = {
'# Modular Digital Communication System and Adaptive MCS'
''
'## Overview'
''
'A modular MATLAB-based digital communication simulation and research project.'
''
'The project evaluates digital modulation, channel coding, fading channels,'
'packet-level reliability, interleaving, and QoS-constrained adaptive MCS.'
''
'## Implemented Modules'
''
'### Modulation'
'- BPSK'
'- QPSK'
'- 16-QAM'
'- Gray-coded mapping'
'- Soft-output LLR demapping'
''
'### Channel Models'
'- AWGN'
'- Rayleigh fading'
'- Rician fading'
'- Block fading'
'- Coherent equalization'
''
'### Channel Coding'
'- Hamming (7,4)'
'- Convolutional coding, rate 1/2'
'- Hard-decision Viterbi decoding'
'- Soft-decision Viterbi decoding'
'- CRC-16/CCITT-FALSE'
''
'### Interleaving and Adaptive Control'
'- Block interleaver and deinterleaver'
'- Adaptive interleaver depth'
'- Adaptive MCS profile selection'
'- PER-constrained QoS policy'
'- Processing and first-column readiness cost metrics'
''
'## Performance Metrics'
''
'- BER, SER, BLER and PER'
'- Throughput and goodput'
'- Effective spectral efficiency'
'- Wilson 95% confidence intervals'
'- Exact paired McNemar tests'
'- Holm-Bonferroni correction'
''
'## Final Experimental Configuration'
''
'- Calibration: 500 packets per profile and operating point'
'- Independent validation: 500 packets per profile and operating point'
'- Deep boundary validation: 3000 packets per profile'
'- Eb/N0 calibration range: 4 to 20 dB'
'- Channels: Rayleigh and Rician'
'- Modulations: BPSK, QPSK and 16-QAM'
'- Interleaver depths: 4 and 16'
'- QoS target: PER upper 95% confidence bound <= 0.20'
''
'## Final Boundary Validation Results'
''
sprintf('- Selected profiles passing QoS: %d/9',numQoSPassed)
sprintf('- Paired comparisons significant after Holm correction: %d/18', ...
    sum(B.PairwiseComparison.SignificantAfterHolm))
''
'QPSK exhibited lower PER than 16-QAM in all 18 equal-depth paired'
'comparisons in the tested boundary conditions.'
''
'16-QAM provides higher effective spectral efficiency, while requiring'
'a higher SNR margin to satisfy the packet-error constraint.'
''
'## Reproduction Scripts'
''
'1. main_mcs_profile_calibration.m'
'2. main_build_adaptive_mcs_policy.m'
'3. main_validate_adaptive_mcs_policy.m'
'4. main_boundary_mcs_validation.m'
'5. main_recompute_boundary_pairwise.m'
''
'## Test Scripts'
''
'- tests/test_build_adaptive_mcs_policy.m'
'- tests/test_adaptive_mcs_validation.m'
'- tests/test_boundary_mcs_validation.m'
''
'## Important Modeling Assumptions'
''
'- Perfect CSI at the receiver.'
'- Four-block fading model.'
'- Convolutional code with generators (7,5), constraint length 3.'
'- CRC-16/CCITT-FALSE.'
'- Eb/N0 referenced to information payload bit energy.'
'- MATLAB processing benchmarks are not hardware latency guarantees.'
''
'## Limitations and Future Work'
''
'- Pilot-based channel estimation.'
'- Imperfect CSI and channel estimation error.'
'- Practical SNR estimation.'
'- Adaptive control signaling overhead.'
'- Hardware and real-time implementation.'
'- Additional FEC schemes such as LDPC and Polar codes.'
''
'## Project Status'
''
'Core simulation, adaptive MCS policy, independent validation,'
'and boundary statistical evaluation have been completed.'
};

readmePath = fullfile(projectRoot,'README.md');

local_write_lines(readmePath,readme);

%% 9. Generate final technical report

report = {
'# Final Technical Validation Report'
''
'## 1. Project'
''
'Modular Digital Communication System Simulation and QoS-Aware Adaptive MCS'
''
'## 2. Calibration'
''
sprintf('Calibration records: %d',height(C.ProfileTable))
sprintf('SNR range: %g to %g dB', ...
    min(C.ProfileTable.EbN0_dB), ...
    max(C.ProfileTable.EbN0_dB))
''
'## 3. Independent Validation'
''
sprintf('Independent profile measurements: %d',height(V.ValidationResults))
''
'## 4. Deep Boundary Validation'
''
sprintf('Packets per profile: %d',B.boundaryConfig.NumPackets)
sprintf('Selected operating points passing QoS: %d of 9',numQoSPassed)
''
'## 5. Paired Statistical Analysis'
''
sprintf('Equal-depth paired comparisons: %d',height(B.PairwiseComparison))
sprintf('Significant after Holm correction: %d', ...
    sum(B.PairwiseComparison.SignificantAfterHolm))
''
'The paired comparisons evaluate QPSK versus 16-QAM at matching'
'interleaver depths using packet-level outcomes.'
''
'## 6. Interpretation'
''
'In the tested boundary operating points, QPSK consistently exhibited'
'lower packet error probability than 16-QAM. The latter provides'
'higher spectral efficiency but requires more SNR margin.'
''
'All nine calibration-selected boundary profiles passed the independent'
'3000-packet QoS validation in the saved experiment.'
''
'## 7. Limitations'
''
'The receiver assumes perfect channel state information. The current'
'implementation does not model pilot overhead, practical channel-estimation'
'error, or adaptive control signaling overhead.'
''
'Measured MATLAB processing time must not be interpreted as hardware'
'or end-to-end link latency.'
''
'## 8. Reproducibility'
''
'Simulation scripts, test scripts, CSV outputs, and MAT datasets are'
'preserved in the project directory.'
};

reportPath = fullfile(reportsDir,'FINAL_TECHNICAL_REPORT.md');

local_write_lines(reportPath,report);

%% 10. Create project manifest

allFiles = dir(fullfile(projectRoot,'**','*'));

manifest = {};

for k = 1:numel(allFiles)

    if allFiles(k).isdir
        continue;
    end

    fullFilePath = fullfile(allFiles(k).folder,allFiles(k).name);

    relativePath = strrep( ...
        fullFilePath,[projectRoot filesep],'');

    manifest{end+1,1} = relativePath;

end

manifestPath = fullfile(reportsDir,'PROJECT_MANIFEST.txt');

local_write_lines(manifestPath,manifest);

%% 11. Create ZIP archive outside project folder

parentDir = fileparts(projectRoot);

[~,projectName] = fileparts(projectRoot);

zipPath = fullfile(parentDir, ...
    [projectName '_FINAL_DELIVERY.zip']);

if exist(zipPath,'file') == 2
    delete(zipPath);
end

zip(zipPath,projectRoot);

%% 12. Final completion report

fprintf('\n=============================================\n');
fprintf(' PROJECT FINALIZATION COMPLETED\n');
fprintf('=============================================\n');

fprintf('README:\n%s\n\n',readmePath);

fprintf('Technical report:\n%s\n\n',reportPath);

fprintf('Manifest:\n%s\n\n',manifestPath);

fprintf('ZIP package:\n%s\n\n',zipPath);

fprintf('All final dataset checks passed.\n');

%% =========================================================
% Local file-writing function
%% =========================================================

function local_write_lines(filePath,lines)

    fid = fopen(filePath,'w');

    if fid < 0
        error('Could not create file: %s',filePath);
    end

    cleanup = onCleanup(@() fclose(fid));

    for k = 1:numel(lines)
        fprintf(fid,'%s\n',lines{k});
    end

end

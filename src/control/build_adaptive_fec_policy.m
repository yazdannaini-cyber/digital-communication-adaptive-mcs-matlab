
function [policyTable,selectedRows] = ...
    build_adaptive_fec_policy(fecResults,targetPER)
%BUILD_ADAPTIVE_FEC_POLICY Build an empirical FEC selection policy.
%
% Candidate systems:
%   Uncoded-BPSK
%   Convolutional-Viterbi
%   LDPC-Normalized-MinSum
%   Polar-SC
%
% Decision:
%   If one or more systems satisfy the QoS constraint:
%       Maximize effective payload spectral efficiency.
%       Tie-break by PER upper confidence bound.
%
%   Otherwise:
%       Minimize PER upper confidence bound.
%       Tie-break by effective payload spectral efficiency.
%
% This is an offline AWGN/SNR lookup policy.
% It is not yet an online channel-adaptive receiver.

    %% Input validation

    if ~istable(fecResults) || isempty(fecResults)
        error('fecResults must be a non-empty table.');
    end

    validateattributes(targetPER,{'numeric'}, ...
        {'scalar','real','finite','>=',0,'<=',1});

    required = {
        'System'
        'EbN0_dB'
        'BER'
        'PER'
        'PER_Upper95'
        'EffectivePayloadSpectralEfficiency'
        'CorrectPayloadSpectralEfficiency'
        'CodedBitsPerPacket'
        'NominalCodeRate'
    };

    missing = setdiff(required, ...
        fecResults.Properties.VariableNames);

    if ~isempty(missing)
        error('Missing variables: %s',strjoin(missing,', '));
    end

    %% Normalize system names

    systems = strtrim(string(fecResults.System));

    if any(ismissing(systems) | systems == "")
        error('System names cannot be empty.');
    end

    validSystems = [
        "Uncoded-BPSK"
        "Convolutional-Viterbi"
        "LDPC-Normalized-MinSum"
        "Polar-SC"
    ];

    if any(~ismember(systems,validSystems))
        error('Unsupported FEC system found.');
    end

    %% Validate numerical columns

    numericNames = {
        'EbN0_dB'
        'BER'
        'PER'
        'PER_Upper95'
        'EffectivePayloadSpectralEfficiency'
        'CorrectPayloadSpectralEfficiency'
        'CodedBitsPerPacket'
        'NominalCodeRate'
    };

    for k = 1:numel(numericNames)

        x = fecResults.(numericNames{k});

        if ~isnumeric(x) || ~isreal(x) || ...
                any(~isfinite(x)) || ...
                numel(x) ~= height(fecResults)

            error('Invalid numerical column: %s',numericNames{k});

        end

    end

    if any(fecResults.PER_Upper95 < fecResults.PER-1e-10) || ...
       any(fecResults.PER_Upper95 > 1)

        error('Invalid PER confidence bounds.');

    end

    %% Operating points

    snrValues = unique(fecResults.EbN0_dB,'sorted');

    %% Initialize output

    SelectedSystem = strings(numel(snrValues),1);

    EbN0_dB = snrValues;

    SelectedBER = zeros(numel(snrValues),1);

    SelectedPER = zeros(numel(snrValues),1);

    PER_Upper95 = zeros(numel(snrValues),1);

    EffectivePayloadRate = zeros(numel(snrValues),1);

    CorrectPayloadRate = zeros(numel(snrValues),1);

    CodedBitsPerPacket = zeros(numel(snrValues),1);

    NominalCodeRate = zeros(numel(snrValues),1);

    QoS_Met = false(numel(snrValues),1);

    FEC_Enabled = false(numel(snrValues),1);

    SelectionMode = strings(numel(snrValues),1);

    NumQoSCompliantCandidates = zeros(numel(snrValues),1);

    selectedIndices = zeros(numel(snrValues),1);

    %% Main policy loop

    for k = 1:numel(snrValues)

        currentSNR = snrValues(k);

        group = find(fecResults.EbN0_dB == currentSNR);

        % Require exactly one record per coding system.
        if numel(group) ~= numel(validSystems) || ...
                numel(unique(systems(group))) ~= numel(validSystems)

            error('Incomplete or duplicate FEC candidates at %.2f dB.', ...
                currentSNR);

        end

        %% QoS-compliant profiles

        qosCandidates = group( ...
            fecResults.PER_Upper95(group) <= targetPER);

        NumQoSCompliantCandidates(k) = numel(qosCandidates);

        if ~isempty(qosCandidates)

            % Maximize useful payload rate.
            % Then minimize PER upper bound.
            % Then maximize correct-payload rate.

            keys = [
                -fecResults.EffectivePayloadSpectralEfficiency(qosCandidates), ...
                 fecResults.PER_Upper95(qosCandidates), ...
                -fecResults.CorrectPayloadSpectralEfficiency(qosCandidates), ...
                 fecResults.CodedBitsPerPacket(qosCandidates)
            ];

            [~,order] = sortrows(keys,[1 2 3 4]);

            selectedIndex = qosCandidates(order(1));

            qosMet = true;

            mode = "QoS-compliant";

        else

            % Best-effort fallback:
            % Minimize PER upper confidence bound first.

            keys = [
                 fecResults.PER_Upper95(group), ...
                -fecResults.EffectivePayloadSpectralEfficiency(group), ...
                -fecResults.CorrectPayloadSpectralEfficiency(group), ...
                 fecResults.CodedBitsPerPacket(group)
            ];

            [~,order] = sortrows(keys,[1 2 3 4]);

            selectedIndex = group(order(1));

            qosMet = false;

            mode = "Best-effort: QoS not met";

        end

        %% Store selection

        selectedIndices(k) = selectedIndex;

        SelectedSystem(k) = systems(selectedIndex);

        SelectedBER(k) = fecResults.BER(selectedIndex);

        SelectedPER(k) = fecResults.PER(selectedIndex);

        PER_Upper95(k) = fecResults.PER_Upper95(selectedIndex);

        EffectivePayloadRate(k) = ...
            fecResults.EffectivePayloadSpectralEfficiency(selectedIndex);

        CorrectPayloadRate(k) = ...
            fecResults.CorrectPayloadSpectralEfficiency(selectedIndex);

        CodedBitsPerPacket(k) = ...
            fecResults.CodedBitsPerPacket(selectedIndex);

        NominalCodeRate(k) = ...
            fecResults.NominalCodeRate(selectedIndex);

        QoS_Met(k) = qosMet;

        FEC_Enabled(k) = SelectedSystem(k) ~= "Uncoded-BPSK";

        SelectionMode(k) = mode;

    end

    %% Construct policy table

    policyTable = table( ...
        EbN0_dB, ...
        SelectedSystem, ...
        SelectedBER, ...
        SelectedPER, ...
        PER_Upper95, ...
        EffectivePayloadRate, ...
        CorrectPayloadRate, ...
        CodedBitsPerPacket, ...
        NominalCodeRate, ...
        QoS_Met, ...
        FEC_Enabled, ...
        NumQoSCompliantCandidates, ...
        SelectionMode);

    selectedRows = fecResults(selectedIndices,:);

end

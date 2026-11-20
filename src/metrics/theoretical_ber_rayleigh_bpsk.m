
function ber = theoretical_ber_rayleigh_bpsk(EbN0_dB)

    % =========================================
    % THEORETICAL BPSK BER OVER RAYLEIGH FADING
    % Perfect CSI and coherent detection
    % =========================================

    %% Validate Input

    if ~isnumeric(EbN0_dB) || ...
       ~isreal(EbN0_dB) || ...
       any(~isfinite(EbN0_dB(:)))

        error('EbN0_dB must contain finite real values.');

    end

    %% Convert Eb/N0 to Linear Scale

    gamma = 10.^(EbN0_dB/10);

    %% Calculate Theoretical BER

    ber = 0.5 .* ...
        (1 - sqrt(gamma ./ (1 + gamma)));

end

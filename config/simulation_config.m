function cfg = simulation_config()

    % =========================================
    % DIGITAL COMMUNICATION SYSTEM CONFIGURATION
    % =========================================

    % Number of information bits
    cfg.numBits = 1e6;

    % Eb/N0 range in dB
    cfg.EbN0_dB = 0:2:12;

    % Modulation scheme
    cfg.modulation = 'BPSK';

    % Channel model
    cfg.channel = 'AWGN';

    % Random seed
    cfg.seed = 42;

end
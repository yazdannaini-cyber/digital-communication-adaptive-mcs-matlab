function symbols = bpsk_modulator(bits)

    % Validate input type
    if ~(isnumeric(bits) || islogical(bits))
        error('Input must be numeric or logical.');
    end

    % Validate input dimensions
    if isempty(bits) || ~isvector(bits)
        error('Input must be a non-empty vector.');
    end

    % Validate binary values
    if ~isreal(bits) || ...
       any(isnan(bits(:)) | isinf(bits(:))) || ...
       any(bits(:) ~= 0 & bits(:) ~= 1)

        error('Input must contain binary values only.');

    end

    % Binary-to-BPSK mapping
    symbols = 1 - 2*double(bits);

end
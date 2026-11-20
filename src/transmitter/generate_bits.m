function bits = generate_bits(N)

    % Validate input
    if ~isnumeric(N) || ~isreal(N) || ...
       ~isscalar(N) || isnan(N) || isinf(N) || ...
       N < 1 || fix(N) ~= N

        error('N must be a positive integer.');

    end

    % Generate equiprobable binary bits
    bits = randi([0 1], 1, N);

end
function H = hamming74_parity_check_matrix()
%HAMMING74_PARITY_CHECK_MATRIX Parity-check matrix for systematic Hamming (7,4).
% Compatible with codeword bit order: [d1 d2 d3 d4 p1 p2 p3].
% A valid codeword c satisfies mod(H*c.',2) == [0;0;0].

H = [1 1 0 1 1 0 0; ...
     1 0 1 1 0 1 0; ...
     0 1 1 1 0 0 1];
end

function G = hamming74_generator_matrix()
%HAMMING74_GENERATOR_MATRIX Generator matrix for systematic Hamming (7,4).
% Codeword bit order: [d1 d2 d3 d4 p1 p2 p3].
% Arithmetic is performed over GF(2).

P = [1 1 0; ...
     1 0 1; ...
     0 1 1; ...
     1 1 1];

G = [eye(4), P];
end

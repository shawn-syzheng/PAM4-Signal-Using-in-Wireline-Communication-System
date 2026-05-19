function y = modulation(x, M)
group_bits = reshape(x, M, []).'; 
d = bi2de(group_bits, 'left-msb');
y = pammod(d, 2^M, 0, 'gray');
y = y.';

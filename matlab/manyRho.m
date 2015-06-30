function [rho, A, B] = manyRho( xincrement, a, b, freqs )
    A = fft(a.*flattopwin(length(a), 'periodic'));
    B = fft(b.*flattopwin(length(b), 'periodic'));
    
    df = 1/xincrement/length(A);
    freqs = floor(freqs./df)+1;
    
    A = A(freqs);
    B = B(freqs);
    
    rho = A./B;
end


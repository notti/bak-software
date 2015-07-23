function status()
    persistent status_i
    
    if isempty(status_i)
        status_i = 1;
    end
    rot = ['|', '/', '-', '\'];
    fprintf('\b%s', rot(status_i));
    status_i = mod(status_i, 4) + 1;
end


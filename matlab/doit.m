function err = doit( ml507 )
    ml507.trigger.arm();
    err = ml507.overlap_add();
    if err ~= 0
        return
    end
    ml507.transmitter.toggle();
end


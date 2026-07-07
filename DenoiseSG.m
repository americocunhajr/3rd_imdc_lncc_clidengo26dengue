function Isg = DenoiseSG(Iobs,polyOrder,frameLen)

    Iobs = max(real(Iobs(:)),0);
    
    if nargin < 2
        polyOrder = 3;
    end
    
    if nargin < 3
        frameLen = 7;
    end
    
    Isg = sgolayfilt(Iobs,polyOrder,frameLen);
    
    Isg = max(real(Isg),0);
    
    if sum(Isg) > 0
        Isg = Isg * sum(Iobs) / sum(Isg);
    end

end
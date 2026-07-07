% -----------------------------------------------------------------
% BriereSmooth.m
% -----------------------------------------------------------------
%  Programmer: Americo Cunha Jr
%              americo.cunhajr@gmail.com
%
%  Originally programmed in: Feb 13, 2025
%            Last update in: Jul 22, 2025
% -----------------------------------------------------------------
% This  function  defines  the smooth version of the generalized 
% Briere function, which is a model to take into account climate
% variables dependence in the growth rate of insects.
% 
%  Input:
%   x     - climate variable (e.g. temperature)
%   xmin  - minimum value for x
%   xmax  - maximum value for x (xmax > xmin)
%   a     - scaling factor (a >= 0)
%   m     - asymmetry factor (m >= 1)
%   delta - fitting factor (0 <= delta <= 1)
%   beta  - smoothness factor of the SoftPlus (beta > 0)
% 
%  Output:
%   B - growth rate (B >= 0)
% -----------------------------------------------------------------
function B = BriereSmooth(x,xmin,xmax,a,m,delta,beta)

    % check number of arguments
    if nargin < 4
        error('Too few inputs.');
    elseif nargin > 7
        error('Too many inputs.');
    elseif nargin == 4
        m     = 2;
        delta = 1.0;
        beta  = 50.0;
    elseif nargin == 5
        delta = 1.0;
        beta  = 50.0;
    elseif nargin == 6
        beta  = 50.0;
    end
    
    % check for consistency
    if xmax <= xmin
        error('xmax must be greater than xmin.');
    elseif a < 0.0
        error('a must be non-negative.');
    elseif m < 1.0
        error('m must greater or equal to one.');
    elseif delta < 0.0 || delta > 1.0 
        error('delta must such that 0 <= delta <= 1.');
    elseif beta <= 0.0
        error('beta must be positive.');
    end

    % Define the SoftPlus function (numerical robust implementation)
    SoftPlus = @(t,b) (1./b).*(log1p(exp(-abs(b.*t)))+max(b.*t,0));
    %SoftPlus = @(t,b) (1./b).*log(1+exp(b.*t));

    % Smooth approximations of (x-xmin) and (xmax-x)
    SmoothMin = SoftPlus(x-xmin,beta);
    SmoothMax = SoftPlus(xmax-x,beta);

    % generalized Briere function with smooth domain limits
    B = a.*(x.*SmoothMin.*SmoothMax.^(1./m)).^delta;
end
% -----------------------------------------------------------------
% -----------------------------------------------------------------
% ZNormalize.m
% -----------------------------------------------------------------
%  Programmer: Americo Cunha Jr
%              americo.cunhajr@gmail.com
%
%  Originally programmed in: Jun 29, 2026
%            Last update in: Jun 29, 2026
% -----------------------------------------------------------------
% Computes the z-score normalized variable.
%
%   Z = ZNormalize(X)
%       Uses the sample mean and sample standard deviation of X.
%
%   Z = ZNormalize(X,mu,sigma)
%       Uses the supplied mean and standard deviation.
%
%   Inputs:
%   X     : input array
%   mu    : mean (optional)
%   sigma : standard deviation (optional)
%
%   Output:
%   Z     : z-score normalized array
%
%   Formula:
%       Z = (X - mu)/sigma
% -----------------------------------------------------------------
function Z = ZNormalize(X,mu,sigma)

    if nargin < 2
        mu = mean(X(:));
    end
    
    if nargin < 3
        sigma = std(X(:));
    end
    
    % Avoid division by zero
    if sigma < eps
        sigma = 1;
    end
    
    Z = (X - mu)/sigma;
end
% -----------------------------------------------------------------
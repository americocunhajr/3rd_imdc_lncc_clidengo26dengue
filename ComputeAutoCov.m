% -----------------------------------------------------------------
% ComputeAutoCov.m
% -----------------------------------------------------------------
%  Programmers: Americo Cunha Jr          <americo.cunhajr@gmail.com>
%               Christian Soize           <christian.soize@univ-eiffel.fr>
%
%  Originally programmed in: Feb 14, 2025
%            Last update in: Jul 11, 2025
% -----------------------------------------------------------------
% This function estimates the sample autocovariance of a univariate
% time series X for lags 0 through maxLag using the time‐average:
%   gamma(h) = (1/(N−h)) sum_{n=1}^{N−h} [X(n+h)−mu][X(n)−mu].
%
% Input:
%   (double N x 1) X      – input time series
%   (int >= 0)     maxLag – maximum lag to compute (default: floor(N/2))
%
% Output:
%   (double 1 x (maxLag+1)) autocov – estimated autocovariance at 
%                                     lags 0:maxLag
%   (double 1 x (maxLag+1)) lags    – vector of lags [0,1,...,maxLag]
% -----------------------------------------------------------------
function [autocov,lags] = ComputeAutoCov(X,maxLag)

    % check number of arguments
    if nargin < 1
        error('Too few inputs.');
    elseif nargin > 2
        error('Too many inputs.');
    end
    
    % check for consistency
    if ~isnumeric(X) || ~isvector(X)
        error('X must be a numeric vector.');
    end
    
    N = numel(X);
    
    % handle maxLag default and validity
    if nargin < 2 || isempty(maxLag)
        maxLag = floor(N/2);
    elseif ~isscalar(maxLag) || maxLag < 0 || maxLag > N-1 || mod(maxLag,1)~=0
        error('maxLag must be an integer between 0 and N−1.');
    end
    
    % pre-allocate memory and compute mean
    mu      = mean(X);
    autocov = zeros(1,maxLag+1);
    lags    = 0:maxLag;
    
    % estimate autocovariance for each lag
    for h = 0:maxLag
        autocov(h+1) = sum((X(1:N-h)-mu).*(X(h+1:N)-mu))/(N-h);
    end
end
% -----------------------------------------------------------------
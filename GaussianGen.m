% -----------------------------------------------------------------
% GaussianGen.m
% -----------------------------------------------------------------
%  Programmers: Americo Cunha Jr
%               americo.cunhajr@gmail.com
%               
%               Christian Soize
%               christian.soize@univ-eiffel.fr
%
%  Originally programmed in: Feb 14, 2025
%            Last update in: Jul 28, 2025
% -----------------------------------------------------------------
% This function generates multiple realizations of a Gaussian
% random vector Y from a univariate time series X using its
% sample autocovariance and Cholesky decomposition:
%   - gamma(h) = autocovariance of X at lag h
%   - Sigma_Y(i,j) = gamma(stride*|i-j|)
%   - Y = mu_X + L*Z,  Z ~ N(0,I),  L*L^T = Sigma_Y
%
% Input:
%   (double N x 1) X      – input time series
%   (int > 0)      stride – lag step size for covariance
%   (int > 0)      nSamp  – dimension of each Y realization
%   (int > 0)      nReal  – number of realizations (default = 1)
%
% Output:
%   (double nSamp x nReal) Y – matrix of Gaussian realizations
% -----------------------------------------------------------------
function Y = GaussianGen(X,stride,nSamp,nReal)

    % check number of arguments
    if nargin < 3
        error('Too few inputs.');
    elseif nargin > 4
        error('Too many inputs.');
    end

    % check for consistency
    if ~isnumeric(X) || ~isvector(X)
        error('X must be a numeric vector.');
    end
    if ~isscalar(stride) || stride<=0 || mod(stride,1)~=0
        error('stride must be a positive integer.');
    end
    if ~isscalar(nSamp) || nSamp<=0 || mod(nSamp,1)~=0
        error('nSamp must be a positive integer.');
    end
    if nargin < 4 || isempty(nReal)
        nReal = 1;
    elseif ~isscalar(nReal) || nReal<=0 || mod(nReal,1)~=0
        error('nReal must be a positive integer.');
    end

    % ensure feasible sampling
    N = numel(X);
    if 1 + (nSamp-1)*stride > N
        error('stride and nSamp exceed length of X.');
    end

    % compute sample mean and max lag
    muX    = mean(X);
    maxLag = stride*(nSamp - 1);

    % estimate autocovariance up to maxLag
    [gammaX, ~] = ComputeAutoCov(X,maxLag);

    % build covariance matrix Sigma_Y
    SigmaY = zeros(nSamp,nSamp);
    for i = 1:nSamp
        for j = 1:nSamp
            lag         = abs(i-j)*stride;
            SigmaY(i,j) = gammaX(lag+1);
        end
    end
    
    % regularize to ensure positive definiteness
    % --- Gershgorin lower‐bound jitter ---
    rowSums    = sum(abs(SigmaY),2) - abs(diag(SigmaY)); % sum_{j~=i}|Sigma_ij|
    gershLower = min(diag(SigmaY) - rowSums);            % <= smallest eigenvalue
    if gershLower <= 0
        epsVal  = eps;                                   % tiny positive floor
        jitter  = (-gershLower + epsVal);
        SigmaY  = SigmaY + jitter*eye(nSamp);
    end

    % Cholesky decomposition
    L = chol(SigmaY,'lower');

    % generate standard normals (each column is an independent sample)
    Z = randn(nSamp,nReal);

    % construct the mean vector for Y.
    muY = muX*ones(nSamp,1);

    % form realizations Y = mu_X + L*Z
    Y = muY + L*Z;
end
% -----------------------------------------------------------------
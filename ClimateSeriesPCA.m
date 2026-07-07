% -----------------------------------------------------------------
% ClimateSeriesPCA.m
% -----------------------------------------------------------------
%  Programmer: Americo Cunha Jr
%
%  Originally programmed in: Jun 29, 2026
%            Last update in: Jun 29, 2026
% -----------------------------------------------------------------
% Build one representative time-series from several highly 
% correlated ones using PCA with user-defined transformations.
%
% Inputs:
%   X       - Nt x Nv matrix of original variables
%   gFun    - function handle: Y = gFun(X)
%   gInvFun - function handle: X = gInvFun(Y)
%
% Outputs:
%   xRep    - Representative series in original physical units
%   Xhat    - Rank-one reconstruction in original physical units
%   info    - PCA diagnostics
% -----------------------------------------------------------------
function [xRep, Xhat, info] = ClimateSeriesPCA(X,gFun,gInvFun)

    % Check data
    [Nt,Nv] = size(X);

    if Nv < 2
        error('At least two variables are required.');
    end

    valid = all(isfinite(X),2);

    Xvalid = X(valid,:);

    % User transformation
    Y = gFun(Xvalid);

    % Center transformed variables
    mu = mean(Y,1);
    Yc = Y - mu;

    % PCA
    [U,S,V] = svd(Yc,'econ');

    score = U(:,1)*S(1,1);
    loading = V(:,1);

    if sum(loading) < 0
        loading = -loading;
        score   = -score;
    end

    % Rank-one reconstruction
    Yhat = mu + score*loading';

    % Return to physical space
    XhatValid = gInvFun(Yhat);

    % Representative series
    xRepValid = mean(XhatValid,2);

    % Restore original indexing
    Xhat          = nan(size(X));
    xRep          = nan(Nt,1);
    Xhat(valid,:) = XhatValid;
    xRep(valid)   = xRepValid;

    % Diagnostics
    sv                 = diag(S);
    info.loading       = loading;
    info.score         = nan(Nt,1);
    info.score(valid)  = score;
    info.explained     = sv.^2/sum(sv.^2);
    info.meanTransform = mu;
end
% -----------------------------------------------------------------